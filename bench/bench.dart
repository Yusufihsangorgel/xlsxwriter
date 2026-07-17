// A write-path benchmark for xlsxwriter: generate a large sheet and report
// wall-clock time and peak resident memory, for both the default (in-memory)
// and constant-memory modes.
//
// Run it with `dart run bench/bench.dart [rows] [cols]`. The defaults are
// 100,000 rows by 10 columns. Peak memory is read from `ProcessInfo.maxRss`,
// which is the peak for the whole process, so each mode is measured in its own
// subprocess (pass `--engine=default` or `--engine=constant-memory` to run just
// one); the top-level invocation spawns each and prints a table.
//
// The comparison against the pure-Dart `excel` package quoted in the README was
// measured separately, because `excel` and this package's test dependency
// `archive` require incompatible major versions and cannot share one pubspec.
import 'dart:io';

import 'package:xlsxwriter/xlsxwriter.dart';

const _defaultRows = 100000;
const _defaultCols = 10;

void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final rows = positional.isNotEmpty ? int.parse(positional[0]) : _defaultRows;
  final cols = positional.length > 1 ? int.parse(positional[1]) : _defaultCols;
  final engine = args
      .firstWhere((a) => a.startsWith('--engine='), orElse: () => '')
      .replaceFirst('--engine=', '');

  if (engine == 'default') {
    _run(rows, cols, constantMemory: false);
    return;
  }
  if (engine == 'constant-memory') {
    _run(rows, cols, constantMemory: true);
    return;
  }

  // Driver: run each mode in a fresh subprocess so peak memory is isolated.
  stdout.writeln(
    'xlsxwriter benchmark: $rows rows x $cols cols (write-only)\n',
  );
  stdout.writeln(
    '${'mode'.padRight(24)}${'time'.padLeft(12)}${'peak RSS'.padLeft(14)}',
  );
  stdout.writeln('-' * 50);
  _spawn('default (in memory)', 'default', rows, cols);
  _spawn('constant memory', 'constant-memory', rows, cols);
}

void _spawn(String label, String engine, int rows, int cols) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'run',
    'bench/bench.dart',
    '--engine=$engine',
    '$rows',
    '$cols',
  ]);
  if (result.exitCode != 0) {
    stdout.writeln('${label.padRight(24)}${'failed'.padLeft(12)}');
    stderr.writeln((result.stderr as String).trim());
    return;
  }
  // The child emits a "RESULT <millis> <peakRssBytes>" marker; find it amid any
  // toolchain output (such as the "Running build hooks..." notice, which is
  // printed without a trailing newline).
  final match = RegExp(
    r'RESULT (\d+) (\d+)',
  ).firstMatch(result.stdout as String);
  if (match == null) {
    stdout.writeln('${label.padRight(24)}${'no result'.padLeft(12)}');
    return;
  }
  final millis = int.parse(match.group(1)!);
  final peakRss = int.parse(match.group(2)!);
  stdout.writeln(
    '${label.padRight(24)}'
    '${'${millis}ms'.padLeft(12)}'
    '${_mib(peakRss).padLeft(14)}',
  );
}

void _run(int rows, int cols, {required bool constantMemory}) {
  final path = _tempPath();
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
  // A marker line the driver can find amid any toolchain output.
  stdout.writeln(
    'RESULT ${stopwatch.elapsedMilliseconds} ${ProcessInfo.maxRss}',
  );
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

String _tempPath() {
  final dir = Directory.systemTemp.createTempSync('xlsxwriter_bench');
  return '${dir.path}${Platform.pathSeparator}out.xlsx';
}

String _mib(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
