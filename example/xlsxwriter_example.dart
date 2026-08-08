// Streams a large export to an .xlsx file, and measures what it cost.
//
// This is the one thing this package does that the pure-Dart writers do not.
// `Workbook.constantMemory` keeps a single row in memory: the row you are
// writing now. Moving to a higher row number serializes the previous row
// straight to XML in a temporary file and frees its cells, so peak memory
// tracks your widest row instead of the size of the sheet. The default
// `Workbook(...)` keeps every cell alive until `close()`, which is fine for a
// report and fatal for an export.
//
// Run it, no arguments needed:
//
//   dart run example/xlsxwriter_example.dart
//   dart run example/xlsxwriter_example.dart --mode=default    # the contrast
//   dart run example/xlsxwriter_example.dart --rows=1000000    # still flat
//   dart run example/xlsxwriter_example.dart --keep            # inspect the file
//
// For formats, tables, images, conditional formatting and charts, see
// example/formatted_report.dart. For an automated head-to-head of both modes,
// see bench/bench.dart.
import 'dart:io';

import 'package:xlsxwriter/xlsxwriter.dart';

/// Big enough that the two modes separate clearly, small enough to finish in
/// about a second. Pass `--rows=` to try a size you actually care about; the
/// point of constant-memory mode is that the peak below does not move.
const _defaultRows = 200000;

void main(List<String> args) {
  final options = _parseArgs(args);

  // ProcessInfo.maxRss is the peak resident set size of the *whole process*
  // over its whole life, not of the workbook. Sampling it before the first
  // write records how high the Dart VM had already climbed on its own, so the
  // difference at the end is the part the export is responsible for. Reporting
  // the raw peak without this subtraction is how a writer gets blamed for the
  // runtime it happens to be hosted in.
  final before = ProcessInfo.maxRss;

  final directory = Directory.systemTemp.createTempSync('xlsxwriter_example');
  final path = '${directory.path}${Platform.pathSeparator}large_export.xlsx';

  final stopwatch = Stopwatch()..start();
  _writeExport(
    path,
    rows: options.rows,
    constantMemory: options.constantMemory,
  );
  stopwatch.stop();

  // Read the peak after close(), because close() is where the sheet XML gets
  // deflated into the zip — the last chance for memory to spike.
  final peak = ProcessInfo.maxRss;
  final fileBytes = File(path).lengthSync();
  final seconds = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

  final mode = options.constantMemory
      ? 'constant memory (Workbook.constantMemory)'
      : 'default (Workbook)';

  stdout
    ..writeln('xlsxwriter: streaming a large export')
    ..writeln()
    ..writeln('  mode        $mode')
    ..writeln(
      '  workload    ${_grouped(options.rows)} '
      '${options.rows == 1 ? 'row' : 'rows'} x 5 columns',
    )
    ..writeln('  wrote       ${_mib(fileBytes)} in ${seconds}s')
    ..writeln()
    ..writeln(
      '  peak RSS   ${_mib(peak).padLeft(10)}   highest this process '
      'reached',
    )
    ..writeln(
      '  before     ${_mib(before).padLeft(10)}   already reached '
      'before the first write',
    )
    ..writeln(
      '  the sheet  ${_mib(peak - before).padLeft(10)}   how much '
      'writing it raised the peak',
    );

  if (options.keep) {
    stdout.writeln('\n  file       $path');
  } else {
    directory.deleteSync(recursive: true);
  }

  stdout.writeln(
    '\nThe last line is the one to watch. In constant-memory mode it stays put\n'
    'as --rows grows, because only one row is ever in memory; on most machines\n'
    'it reads 0.0 MiB, meaning the export never pushed the process past where\n'
    'the VM had already been. Re-run with --mode=default to build the same\n'
    'sheet in memory and watch that line grow with the row count instead.\n'
    '\n'
    'Peak RSS is a whole-process number, so the two modes have to be separate\n'
    'runs: in one process whichever peaked higher would hide the other. That\n'
    'is what bench/bench.dart automates.',
  );

  _showOrderingRule();
}

/// Writes [rows] rows of order data to [path].
///
/// Nothing here is specific to constant-memory mode except the constructor:
/// the same calls in the same order work in either mode. That is the point —
/// switching an export over is a one-line change, as long as it already writes
/// top to bottom.
void _writeExport(
  String path, {
  required int rows,
  required bool constantMemory,
}) {
  final workbook = constantMemory
      ? Workbook.constantMemory(path)
      : Workbook(path);
  try {
    final sheet = workbook.addWorksheet('Orders');

    final header = workbook.addFormat()
      ..bold()
      ..fontColor(0xFFFFFF)
      ..backgroundColor(0x4472C4);
    final money = workbook.addFormat()..numberFormat(r'$#,##0.00');

    // Column widths, a column-wide number format and frozen panes are sheet
    // properties rather than cells, so they cost nothing per row and are worth
    // setting up front. Giving the money columns their format here, instead of
    // passing a format to every writeRow, keeps the hot loop to just data:
    // a cell with no format of its own inherits its column's.
    sheet
      ..setColumn(0, 0, 14)
      ..setColumn(1, 1, 22)
      ..setColumn(2, 2, 10)
      ..setColumn(3, 4, 12, money)
      ..freezePanes(1, 0);

    sheet.writeRow(0, const [
      'Order',
      'Customer',
      'Units',
      'Unit price',
      'Total',
    ], format: header);

    // The export itself: top to bottom, one row at a time. Nothing accumulates
    // on either side of the boundary. libxlsxwriter flushes row n-1 when row n
    // starts, and the list built here is garbage as soon as writeRow returns.
    for (var row = 1; row <= rows; row++) {
      final units = row % 97 + 1;
      final unitPrice = (row % 500 + 50) / 10;
      sheet.writeRow(row, [
        'SO-${row.toString().padLeft(7, '0')}',
        'Customer ${row % 5000}',
        units,
        unitPrice,
        units * unitPrice,
      ]);
    }
  } finally {
    // close() is the call that writes the file. A try/finally makes sure the
    // native workbook is released even if the loop above throws.
    workbook.close();
  }
}

/// Shows the single rule constant-memory mode adds, using the errors you
/// actually get rather than describing them.
void _showOrderingRule() {
  final directory = Directory.systemTemp.createTempSync('xlsxwriter_rule');
  try {
    final workbook = Workbook.constantMemory(
      '${directory.path}${Platform.pathSeparator}rule.xlsx',
    );
    final sheet = workbook.addWorksheet('Orders');
    sheet.writeRow(0, const ['Order', 'Customer']);
    sheet.writeRow(1, const ['SO-0000001', 'Customer 1']);
    // Writing row 1 flushed row 0. It is XML in a temp file now, and its cells
    // have been freed, so there is nothing left to change.

    stdout.writeln(
      '\nThe rule constant-memory mode adds: write top to bottom.',
    );

    try {
      sheet.writeString(0, 2, 'a late note on the header row');
      stdout.writeln('  writeString(0, 2, ...)      -> accepted');
    } on XlsxWriterException catch (error) {
      // Worth reading this message closely, because it is misleading: the
      // index is perfectly in range, the row is simply gone. If a
      // constant-memory sheet ever reports "index out of range", look for a
      // write that goes backwards before you go looking for a bad index.
      stdout.writeln('  writeString(0, 2, ...)      -> ${error.message}');
    }

    try {
      sheet.mergeRange(0, 0, 0, 4, 'Q3 orders');
      stdout.writeln('  mergeRange(0, 0, 0, 4, ...) -> accepted');
    } on ArgumentError catch (error) {
      // libxlsxwriter drops a merge that reaches back into flushed rows and
      // reports nothing, so this package checks the range itself rather than
      // hand back a sheet that is silently missing its title.
      stdout.writeln('  mergeRange(0, 0, 0, 4, ...) -> ${error.message}');
    }

    workbook.close();

    stdout.writeln(
      '\nBoth calls are legal in default mode. Column order within the row you\n'
      'are on does not matter in either mode; only row order does.',
    );
  } finally {
    directory.deleteSync(recursive: true);
  }
}

({int rows, bool constantMemory, bool keep}) _parseArgs(List<String> args) {
  var rows = _defaultRows;
  var constantMemory = true;
  var keep = false;
  for (final arg in args) {
    switch (arg) {
      case '--keep':
        keep = true;
      case '--mode=constant-memory':
        constantMemory = true;
      case '--mode=default':
        constantMemory = false;
      case _ when arg.startsWith('--rows='):
        final value = int.tryParse(arg.substring('--rows='.length));
        if (value == null || value < 1) {
          _usageError('--rows needs a positive integer, got "$arg"');
        }
        rows = value;
      default:
        _usageError('unknown option "$arg"');
    }
  }
  return (rows: rows, constantMemory: constantMemory, keep: keep);
}

Never _usageError(String message) {
  stderr
    ..writeln('xlsxwriter_example: $message')
    ..writeln(
      'usage: dart run example/xlsxwriter_example.dart '
      '[--rows=N] [--mode=default|constant-memory] [--keep]',
    );
  exit(64); // EX_USAGE
}

String _mib(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

/// `1234567` as `1,234,567`, so the row count stays readable at a glance.
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
