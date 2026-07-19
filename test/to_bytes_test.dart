import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

import 'xlsx_reader.dart';

void main() {
  test('toBytes returns a valid xlsx carrying the written content', () {
    final bytes = Workbook.toBytes((workbook) {
      final sheet = workbook.addWorksheet('Summary');
      sheet.writeString(0, 0, 'Item');
      sheet.writeNumber(0, 1, 42);
    });

    // It is a real zip container (the "PK" local-file-header signature).
    expect(bytes.length, greaterThan(0));
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);

    // And it reads back with the content that was written.
    final dir = Directory.systemTemp.createTempSync('xlsxwriter_tobytes');
    try {
      final path = '${dir.path}${Platform.pathSeparator}out.xlsx';
      File(path).writeAsBytesSync(bytes);
      final file = XlsxFile.read(path);
      expect(file.hasMember('xl/worksheets/sheet1.xml'), isTrue);
      expect(file.xml('xl/sharedStrings.xml').toString(), contains('Item'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('toBytes in constant-memory mode also produces a valid xlsx', () {
    final bytes = Workbook.toBytes((workbook) {
      final sheet = workbook.addWorksheet();
      for (var row = 0; row < 100; row++) {
        sheet.writeString(row, 0, 'row $row');
      }
    }, constantMemory: true);
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);
    expect(bytes.length, greaterThan(500));
  });
}
