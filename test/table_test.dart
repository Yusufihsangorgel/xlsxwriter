import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';
import 'package:xml/xml.dart';

import 'xlsx_reader.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xlsxwriter_table_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String pathFor(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  /// Writes a 3-column, 3-row table with a header row.
  XlsxFile buildWithTable(
    String path, {
    String? name,
    bool autofilter = true,
    bool bandedRows = true,
  }) {
    final workbook = Workbook(path);
    final sheet = workbook.addWorksheet();
    for (final (col, header) in ['Item', 'Qty', 'Price'].indexed) {
      sheet.writeString(0, col, header);
    }
    for (var row = 1; row <= 3; row++) {
      sheet.writeString(row, 0, 'item-$row');
      sheet.writeNumber(row, 1, row * 2);
      sheet.writeNumber(row, 2, row * 1.5);
    }
    sheet.addTable(
      0,
      0,
      3,
      2,
      name: name,
      columns: const ['Item', 'Qty', 'Price'],
      autofilter: autofilter,
      bandedRows: bandedRows,
    );
    workbook.close();
    return XlsxFile.read(path);
  }

  test('writes a table part covering the range', () {
    final file = buildWithTable(pathFor('table.xlsx'), name: 'Sales');
    expect(file.hasMember('xl/tables/table1.xml'), isTrue);
    final table = file.xml('xl/tables/table1.xml').rootElement;
    expect(table.getAttribute('ref'), 'A1:C4');
    expect(table.getAttribute('displayName'), 'Sales');
  });

  test('uses the header row cells as column names', () {
    final file = buildWithTable(pathFor('columns.xlsx'), name: 'Sales');
    final columns = file
        .xml('xl/tables/table1.xml')
        .rootElement
        .findAllElements('tableColumn')
        .map((c) => c.getAttribute('name'))
        .toList();
    expect(columns, ['Item', 'Qty', 'Price']);
  });

  test('autofilter is present by default and can be turned off', () {
    final withFilter = buildWithTable(pathFor('filter.xlsx'), name: 'A');
    expect(
      withFilter.xml('xl/tables/table1.xml').findAllElements('autoFilter'),
      isNotEmpty,
    );
    final noFilter = buildWithTable(
      pathFor('nofilter.xlsx'),
      name: 'B',
      autofilter: false,
    );
    expect(
      noFilter.xml('xl/tables/table1.xml').findAllElements('autoFilter'),
      isEmpty,
    );
  });

  test('a table with an auto-generated name is still valid', () {
    final path = pathFor('auto_name.xlsx');
    final file = buildWithTable(path); // no explicit name
    expect(file.hasMember('xl/tables/table1.xml'), isTrue);
    expect(
      file.xml('xl/tables/table1.xml').rootElement.getAttribute('displayName'),
      isNotNull,
    );
  });

  test('rejects a columns list that does not match the range width', () {
    final workbook = Workbook(pathFor('mismatch.xlsx'));
    final sheet = workbook.addWorksheet();
    addTearDown(workbook.close);
    expect(
      () => sheet.addTable(0, 0, 3, 2, columns: const ['only', 'two']),
      throwsArgumentError,
    );
  });
}
