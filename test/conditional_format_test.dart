import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

import 'xlsx_reader.dart';

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('xlsxcf'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });
  String pathFor(String n) => '${tempDir.path}/$n';

  // The XML for every conditional rule lives in a <conditionalFormatting> block
  // in the sheet. Assert that the file both is valid (reads back) and carries
  // the rule of the expected type.
  String sheetXml(String path) =>
      XlsxFile.read(path).text('xl/worksheets/sheet1.xml');

  test('conditionalCell writes a cellIs rule', () {
    final path = pathFor('cell.xlsx');
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet();
    for (var r = 0; r < 5; r++) {
      sheet.writeNumber(r, 0, r * 100);
    }
    final red = workbook.addFormat().backgroundColor(0xFFC7CE);
    sheet.conditionalCell(
      0,
      0,
      4,
      0,
      criteria: ConditionalCriteria.greaterThan,
      value: 150,
      format: red,
    );
    workbook.close();

    final xml = sheetXml(path);
    expect(xml, contains('conditionalFormatting'));
    expect(xml, contains('cellIs'));
    expect(xml, contains('greaterThan'));
  });

  test('conditionalCellBetween writes a between rule', () {
    final path = pathFor('between.xlsx');
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet();
    sheet.writeNumber(0, 0, 50);
    final fmt = workbook.addFormat().backgroundColor(0xFFEB9C);
    sheet.conditionalCellBetween(0, 0, 9, 0, min: 10, max: 90, format: fmt);
    workbook.close();

    final xml = sheetXml(path);
    expect(xml, contains('cellIs'));
    expect(xml, contains('between'));
  });

  test('conditionalColorScale writes a 2-colour and a 3-colour scale', () {
    final path2 = pathFor('scale2.xlsx');
    var workbook = Workbook(path2);
    workbook.addWorksheet().conditionalColorScale(
      0,
      0,
      9,
      0,
      minColor: 0xF8696B,
      maxColor: 0x63BE7B,
    );
    workbook.close();
    expect(sheetXml(path2), contains('colorScale'));

    final path3 = pathFor('scale3.xlsx');
    workbook = Workbook(path3);
    workbook.addWorksheet().conditionalColorScale(
      0,
      0,
      9,
      0,
      minColor: 0xF8696B,
      midColor: 0xFFEB84,
      maxColor: 0x63BE7B,
    );
    workbook.close();
    final xml3 = sheetXml(path3);
    expect(xml3, contains('colorScale'));
    // A 3-colour scale has three cfvo/color entries; the mid colour proves it.
    expect(xml3, contains('FFEB84'));
  });

  test('conditionalDataBar writes a dataBar rule', () {
    final path = pathFor('bar.xlsx');
    final workbook = Workbook(path);
    workbook.addWorksheet().conditionalDataBar(0, 0, 9, 0, barColor: 0x638EC6);
    workbook.close();

    final xml = sheetXml(path);
    expect(xml, contains('dataBar'));
    expect(xml.toUpperCase(), contains('638EC6'));
  });
}
