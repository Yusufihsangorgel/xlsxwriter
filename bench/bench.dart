// A write-path benchmark for the three engines the README compares: this
// package in both modes, the unmaintained pure-Dart `excel` 4.0.6, and its
// maintained fork `excel_community`.
//
// Run it from the package root:
//
//   dart run bench/bench.dart [rows] [cols] [--runs=N] [--compare]
//       [--engine=NAME]
//
// The defaults are 100,000 rows by 10 columns, one run of the two xlsxwriter
// modes. `--compare` adds `excel` 4.0.6 and `excel_community` 2.3.0, which is
// what the README table is regenerated from (`--runs=5 --compare`). `--engine=`
// limits the driver to one of `default`, `constant-memory`, `excel`,
// `excel_community`. Competitors are opt-in so `dart run bench/bench.dart
// 1000000 10` still measures only this package, at a size the pure-Dart
// writers may not fit in RAM.
//
// Peak memory is `ProcessInfo.maxRss`, the high-water mark of resident set
// size for the whole process (Dart's wrapper around `getrusage` `ru_maxrss`).
// That is a process-level proxy, not a heap profile of the workbook: it
// includes the VM, JIT, and any native library, and it only ever goes up. Two
// consequences follow, and both are why the table has four columns.
//
// 1. Each engine is a separate process. In one process the higher peak would
//    hide the other. `excel` 4.0.6 also cannot share a pubspec with this
//    package's tests (`archive` ^3 vs ^4), so the two pure-Dart engines live
//    under `bench/competitors/` and the driver spawns them there.
// 2. A Dart VM with this package loaded already sits near 188 MiB before it
//    writes a cell. Every child therefore samples `maxRss` once before the
//    first write ("baseline") and reports the difference ("the sheet") too.
//    The last column is the only one about the writer.
//
// The child for the two xlsxwriter modes is this same file with
// `--engine=default` or `--engine=constant-memory` and no `--runs`. The
// pure-Dart children are `bench/competitors/*/bin/bench.dart`. All four emit
// `RESULT <millis> <peakRssBytes> <baselineRssBytes>`.
import 'dart:io';

import 'package:xlsxwriter/xlsxwriter.dart';

const _defaultRows = 100000;
const _defaultCols = 10;

const _engines = [
  _Engine(id: 'constant-memory', label: 'xlsxwriter (constant memory)'),
  _Engine(id: 'default', label: 'xlsxwriter (default)'),
  _Engine(
    id: 'excel',
    label: 'excel 4.0.6 (pure Dart)',
    competitorDir: 'bench/competitors/excel',
  ),
  _Engine(
    id: 'excel_community',
    label: 'excel_community 2.3.0 (pure Dart)',
    competitorDir: 'bench/competitors/excel_community',
  ),
];

void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final rows = positional.isNotEmpty ? int.parse(positional[0]) : _defaultRows;
  final cols = positional.length > 1 ? int.parse(positional[1]) : _defaultCols;
  final engine = _flag(args, 'engine');
  final runsFlag = _flag(args, 'runs');
  final runs = runsFlag == null ? 1 : int.parse(runsFlag);
  final compare = args.contains('--compare');

  if (rows <= 0 || cols <= 0 || runs <= 0) {
    stderr.writeln('rows, cols and --runs must be positive');
    exit(1);
  }

  // Child: one xlsxwriter mode, this process. The driver never takes this
  // path when `--runs` is present, so a median of five is five processes
  // rather than one process whose maxRss is the max of all five.
  if ((engine == 'default' || engine == 'constant-memory') &&
      runsFlag == null) {
    _run(rows, cols, constantMemory: engine == 'constant-memory');
    return;
  }

  if (!File('bench/bench.dart').existsSync()) {
    stderr.writeln(
      'run this from the package root: bench/bench.dart not found in '
      '${Directory.current.path}',
    );
    exit(1);
  }

  final selected = _select(engine, compare: compare);
  _ensureCompetitors(selected);
  // Pay for compiles (the native hook, and the competitor isolates) on a
  // tiny sheet, so the first timed run is the export rather than the toolchain.
  for (final item in selected) {
    _spawnEngine(item, 10, cols);
  }

  stdout.writeln(
    'xlsxwriter benchmark: $rows rows x $cols cols, '
    '$runs run${runs == 1 ? '' : 's'} per engine (write-only)\n',
  );
  stdout.writeln(
    '${'engine'.padRight(40)}${'time'.padLeft(10)}${'peak RSS'.padLeft(13)}'
    '${'baseline'.padLeft(13)}${'the sheet'.padLeft(13)}',
  );
  stdout.writeln('-' * 89);

  for (final item in selected) {
    final samples = <_Sample>[];
    for (var i = 0; i < runs; i++) {
      if (i > 0) {
        // Let the OS reclaim the previous child's pages before the next
        // isolated peak-RSS sample, otherwise a busy machine reports the
        // writer as slower and slimmer than it is.
        sleep(const Duration(seconds: 2));
      }
      final sample = _spawnEngine(item, rows, cols);
      samples.add(sample);
      if (runs > 1) {
        stdout.writeln(
          '${'  run ${i + 1}'.padRight(40)}'
          '${'${sample.millis}ms'.padLeft(10)}'
          '${_mib(sample.peakRss).padLeft(13)}'
          '${_mib(sample.baselineRss).padLeft(13)}'
          '${_mib(sample.sheetRss).padLeft(13)}',
        );
      }
    }
    final shown = runs == 1 ? samples.single : _median(samples);
    final suffix = runs == 1 ? '' : '  (median of $runs)';
    stdout.writeln(
      '${item.label.padRight(40)}'
      '${'${shown.millis}ms'.padLeft(10)}'
      '${_mib(shown.peakRss).padLeft(13)}'
      '${_mib(shown.baselineRss).padLeft(13)}'
      '${_mib(shown.sheetRss).padLeft(13)}'
      '$suffix',
    );
  }

  stdout.writeln(
    '\n"peak RSS" is ProcessInfo.maxRss, the highest resident-set size the\n'
    'whole process reached. It is a process-level proxy (VM + JIT + native\n'
    'code + the sheet), not a heap profile of the workbook. "baseline" is\n'
    'that same counter sampled before the first write. "the sheet" is the\n'
    'difference: the only column that is about the writer. Each engine runs\n'
    'in its own process because maxRss only ever goes up. The README table\n'
    'is this output at 100,000 x 10 with --runs=5 --compare; each column is\n'
    'its own median, so "the sheet" is not the difference of the two beside it.',
  );
}

String? _flag(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

List<_Engine> _select(String? engine, {required bool compare}) {
  if (engine == null || engine.isEmpty) {
    if (compare) return _engines;
    return [
      for (final e in _engines)
        if (e.competitorDir == null) e,
    ];
  }
  final match = _engines.where((e) => e.id == engine).toList();
  if (match.isEmpty) {
    stderr.writeln(
      'unknown --engine=$engine; want one of: '
      '${_engines.map((e) => e.id).join(', ')}',
    );
    exit(1);
  }
  return match;
}

void _ensureCompetitors(List<_Engine> selected) {
  for (final item in selected) {
    final dir = item.competitorDir;
    if (dir == null) continue;
    if (!File('$dir/pubspec.yaml').existsSync()) {
      stderr.writeln('missing competitor harness: $dir/pubspec.yaml');
      exit(1);
    }
    final result = Process.runSync(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: dir);
    if (result.exitCode != 0) {
      stderr
        ..writeln('dart pub get failed in $dir')
        ..writeln((result.stderr as String).trim());
      exit(result.exitCode);
    }
  }
}

_Sample _spawnEngine(_Engine engine, int rows, int cols) {
  final ProcessResult result;
  if (engine.competitorDir == null) {
    result = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'bench/bench.dart',
      '--engine=${engine.id}',
      '$rows',
      '$cols',
    ]);
  } else {
    result = Process.runSync(Platform.resolvedExecutable, [
      'run',
      'bin/bench.dart',
      '$rows',
      '$cols',
    ], workingDirectory: engine.competitorDir);
  }
  if (result.exitCode != 0) {
    stderr
      ..writeln('${engine.label} failed with exit code ${result.exitCode}')
      ..writeln((result.stderr as String).trim())
      ..writeln((result.stdout as String).trim());
    exit(result.exitCode);
  }
  final match = RegExp(
    r'RESULT (\d+) (\d+) (\d+)',
  ).firstMatch(result.stdout as String);
  if (match == null) {
    stderr.writeln('${engine.label} printed no RESULT line');
    stderr.writeln((result.stdout as String).trim());
    exit(1);
  }
  final millis = int.parse(match.group(1)!);
  final peakRss = int.parse(match.group(2)!);
  final baselineRss = int.parse(match.group(3)!);
  return _Sample(
    millis: millis,
    peakRss: peakRss,
    baselineRss: baselineRss,
    sheetRss: peakRss - baselineRss,
  );
}

_Sample _median(List<_Sample> samples) {
  int mid(List<int> xs) {
    final s = [...xs]..sort();
    final n = s.length;
    if (n.isOdd) return s[n ~/ 2];
    return (s[n ~/ 2 - 1] + s[n ~/ 2]) ~/ 2;
  }

  // Each column is its own median, matching the README: "the sheet" is not
  // the difference of the two columns beside it.
  return _Sample(
    millis: mid([for (final s in samples) s.millis]),
    peakRss: mid([for (final s in samples) s.peakRss]),
    baselineRss: mid([for (final s in samples) s.baselineRss]),
    sheetRss: mid([for (final s in samples) s.sheetRss]),
  );
}

void _run(int rows, int cols, {required bool constantMemory}) {
  final path = _tempPath();
  // Sampled before the first write and after the package is loaded, so it
  // records how high the VM had already climbed on its own. maxRss only ever
  // goes up, so the difference at the end belongs to the export.
  final baselineRss = ProcessInfo.maxRss;
  final stopwatch = Stopwatch()..start();
  final workbook = constantMemory
      ? Workbook.constantMemory(path)
      : Workbook(path);
  final sheet = workbook.addWorksheet('Data');
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      if (col == 0) {
        sheet.writeString(row, col, 'r${row}c$col');
      } else {
        sheet.writeNumber(row, col, row * cols + col);
      }
    }
  }
  workbook.close();
  stopwatch.stop();
  // Read the peak after close(), which is where the sheet XML is deflated into
  // the zip: the last chance for memory to spike.
  final peakRss = ProcessInfo.maxRss;
  stdout.writeln(
    'RESULT ${stopwatch.elapsedMilliseconds} $peakRss $baselineRss',
  );
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

String _tempPath() {
  final dir = Directory.systemTemp.createTempSync('xlsxwriter_bench');
  return '${dir.path}${Platform.pathSeparator}out.xlsx';
}

String _mib(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

class _Engine {
  const _Engine({required this.id, required this.label, this.competitorDir});

  final String id;
  final String label;
  final String? competitorDir;
}

class _Sample {
  const _Sample({
    required this.millis,
    required this.peakRss,
    required this.baselineRss,
    required this.sheetRss,
  });

  final int millis;
  final int peakRss;
  final int baselineRss;
  final int sheetRss;
}
