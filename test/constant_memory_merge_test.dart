import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

/// The README used to say merged ranges do not work in constant-memory mode.
/// They do, under the same write-forward rule as everything else: a range at
/// or ahead of the current row is written, one reaching back into flushed
/// rows throws. These pin that contract.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('xlsx_cm_merge'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a forward merge is written in constant-memory mode', () {
    final path = '${dir.path}/forward.xlsx';
    final workbook = Workbook.constantMemory(path);
    workbook.addWorksheet('s')
      ..mergeRange(0, 0, 0, 3, 'merged header')
      ..writeRow(1, ['a', 'b']);
    workbook.close();

    expect(File(path).lengthSync(), greaterThan(0));
  });

  test('merging back into an already-flushed row throws', () {
    final path = '${dir.path}/backward.xlsx';
    final workbook = Workbook.constantMemory(path);
    final sheet = workbook.addWorksheet('s')..writeRow(5, ['x']);

    expect(
      () => sheet.mergeRange(0, 0, 0, 3, 'back'),
      throwsA(isA<XlsxWriterException>()),
    );

    try {
      workbook.close();
    } on XlsxWriterException {
      // Closing after the rejected merge is not what this test pins.
    }
  });
}
