// Runs inside the app the compat workflow generates, not in this package:
// flutter_test and integration_test resolve there. tool/ci/prepare_app.dart
// copies it to the app's integration_test directory.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('writes a workbook to the temp directory', () {
    final dir = Directory.systemTemp.createTempSync('xlsxwriter_compat');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/report.xlsx';

    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet('Summary');
    sheet.writeString(0, 0, 'Item');
    sheet.writeNumber(0, 1, 1250);
    workbook.close();

    final bytes = File(path).readAsBytesSync();
    // A ZIP local file header, and the entry names are stored uncompressed.
    expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
    final text = latin1.decode(bytes);
    expect(text, contains('xl/workbook.xml'));
    expect(text, contains('xl/worksheets/sheet1.xml'));
  });

  test('rejects a duplicate worksheet name with XlsxWriterException', () {
    final dir = Directory.systemTemp.createTempSync('xlsxwriter_compat');
    addTearDown(() => dir.deleteSync(recursive: true));
    final workbook = Workbook('${dir.path}/duplicate.xlsx')
      ..addWorksheet('Data');
    addTearDown(workbook.close);

    expect(
      () => workbook.addWorksheet('Data'),
      throwsA(isA<XlsxWriterException>()),
    );
  });
}
