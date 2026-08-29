import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';
import 'package:xml/xml.dart';

import 'xlsx_reader.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xlsxwriter_layout_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String pathFor(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  test('autofilter writes an autoFilter ref covering the range', () {
    final path = pathFor('autofilter.xlsx');
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet();
    sheet.writeRow(0, const ['Item', 'Region', 'Units']);
    for (var row = 1; row <= 4; row++) {
      sheet.writeRow(row, ['item-$row', 'East', row * 10]);
    }
    sheet.autofilter(0, 0, 4, 2);
    workbook.close();

    final file = XlsxFile.read(path);
    final filters = file.sheet(1).findAllElements('autoFilter');
    expect(filters, isNotEmpty);
    expect(filters.first.getAttribute('ref'), 'A1:C5');
  });

  test('freezePanes writes a frozen pane split', () {
    final path = pathFor('freeze.xlsx');
    final workbook = Workbook(path);
    workbook.addWorksheet().freezePanes(1, 0);
    workbook.close();

    final pane = XlsxFile.read(path).sheet(1).findAllElements('pane').first;
    expect(pane.getAttribute('ySplit'), '1');
    expect(pane.getAttribute('state'), 'frozen');
  });

  test('freezePanes on a column writes xSplit', () {
    final path = pathFor('freeze_col.xlsx');
    final workbook = Workbook(path);
    workbook.addWorksheet().freezePanes(0, 1);
    workbook.close();

    final pane = XlsxFile.read(path).sheet(1).findAllElements('pane').first;
    expect(pane.getAttribute('xSplit'), '1');
    expect(pane.getAttribute('state'), 'frozen');
  });

  test('defineName writes a definedName the formula can use', () {
    final path = pathFor('defined_name.xlsx');
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet('Rates');
    sheet.writeNumber(0, 0, 100);
    workbook.defineName('Exchange_rate', '=0.96');
    sheet.writeFormula(1, 0, '=A1*Exchange_rate');
    workbook.close();

    final names = XlsxFile.read(path).workbook.findAllElements('definedName');
    final rate = names.where((n) => n.getAttribute('name') == 'Exchange_rate');
    expect(rate, isNotEmpty);
    expect(rate.first.innerText, '0.96');
  });

  test('a sheet-local defined name carries localSheetId', () {
    final path = pathFor('local_name.xlsx');
    final workbook = Workbook(path);
    workbook.addWorksheet('First');
    final second = workbook.addWorksheet('Second');
    second.writeNumber(0, 0, 10);
    workbook.defineName('Second!Sales', r'=Second!$A$1');
    workbook.close();

    final names = XlsxFile.read(path).workbook.findAllElements('definedName');
    final sales = names.where((n) => n.getAttribute('name') == 'Sales');
    expect(sales, isNotEmpty);
    expect(sales.first.getAttribute('localSheetId'), '1');
    expect(sales.first.innerText, r'Second!$A$1');
  });

  test('autofilter and defineName after close throw StateError', () {
    final path = pathFor('closed.xlsx');
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet();
    workbook.close();
    expect(() => sheet.autofilter(0, 0, 1, 1), throwsStateError);
    expect(() => sheet.freezePanes(1, 0), throwsStateError);
    expect(() => workbook.defineName('X', '=1'), throwsStateError);
  });

  test('defineName rejects an embedded NUL instead of truncating', () {
    final path = pathFor('nul.xlsx');
    final workbook = Workbook(path)..addWorksheet();
    addTearDown(workbook.close);
    expect(
      () => workbook.defineName('bad\u0000name', '=1'),
      throwsArgumentError,
    );
    expect(() => workbook.defineName('ok', '=A1\u0000'), throwsArgumentError);
  });
}
