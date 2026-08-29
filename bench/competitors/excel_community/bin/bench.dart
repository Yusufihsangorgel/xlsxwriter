// Same write-path workload as ../../../bench.dart, for `excel_community`
// 2.3.0. Isolated in its own package so its archive ^4 dependency does not
// collide with excel 4.0.6's archive ^3, and so a comparison against only
// the unmaintained package cannot happen by accident. Invoked by the driver;
// run directly with `dart run bin/bench.dart [rows] [cols]`.
import 'dart:io';

import 'package:excel_community/excel_community.dart';

void main(List<String> args) {
  final rows = args.isNotEmpty ? int.parse(args[0]) : 100000;
  final cols = args.length > 1 ? int.parse(args[1]) : 10;
  final dir = Directory.systemTemp.createTempSync('excel_community_bench');
  final path = '${dir.path}${Platform.pathSeparator}out.xlsx';

  // Sampled after the library is loaded and before the first write, matching
  // the xlsxwriter harness: maxRss only ever goes up, so the difference at
  // the end belongs to the export.
  final baselineRss = ProcessInfo.maxRss;
  final stopwatch = Stopwatch()..start();

  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];
  // Same nested loop as ../../bench.dart: one text column, the rest integers.
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final index = CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
      sheet.updateCell(
        index,
        col == 0
            ? TextCellValue('r${row}c$col')
            : IntCellValue(row * cols + col),
      );
    }
  }
  final bytes = book.save();
  if (bytes == null) {
    stderr.writeln('excel_community.save() returned null');
    exit(1);
  }
  File(path).writeAsBytesSync(bytes);

  stopwatch.stop();
  final peakRss = ProcessInfo.maxRss;
  stdout.writeln(
    'RESULT ${stopwatch.elapsedMilliseconds} $peakRss $baselineRss',
  );
  dir.deleteSync(recursive: true);
}
