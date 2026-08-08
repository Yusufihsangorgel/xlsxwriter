// A small formatted report: merged and colored title, styled headers, number
// and currency formats, a live formula, a date column, column widths, frozen
// panes, and a column chart.
//
// This is the presentation side of the package. Charts in particular are a
// reason to reach for a native writer: the pure-Dart writers cannot produce
// them at all. Everything here uses the default `Workbook(...)`, which holds
// the whole workbook in memory — the right choice for a report of this size,
// because it lets you write cells in any order.
//
// For a large export that must not fit in RAM, see
// example/xlsxwriter_example.dart.
//
// Run it with `dart run example/formatted_report.dart`; it prints the path of
// the file it wrote, for you to open in Excel, Numbers, or LibreOffice.
import 'dart:io';

import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  // Write into a temporary directory rather than the current one, so running
  // the example does not leave a file in whatever directory you happened to be
  // in. The path is printed at the end.
  final directory = Directory.systemTemp.createTempSync('xlsxwriter_report');
  final path = '${directory.path}${Platform.pathSeparator}report.xlsx';

  final workbook = Workbook(path);
  try {
    final sheet = workbook.addWorksheet('Sales');

    // A bold, colored, centered title merged across the table width.
    final title = workbook.addFormat()
      ..bold()
      ..fontSize(14)
      ..fontColor(0xFFFFFF)
      ..backgroundColor(0x4472C4)
      ..align(HorizontalAlignment.center)
      ..verticalAlign(VerticalAlignment.center);
    sheet.mergeRange(0, 0, 0, 3, 'Quarterly Sales', title);
    sheet.setRow(0, 24);

    // Column headers.
    final header = workbook.addFormat()
      ..bold()
      ..border(CellBorder.thin)
      ..backgroundColor(0xD9E1F2);
    const headings = ['Item', 'Units', 'Unit Price', 'Total'];
    for (var col = 0; col < headings.length; col++) {
      sheet.writeString(1, col, headings[col], header);
    }

    // Data rows with number and currency formats.
    final currency = workbook.addFormat()..numberFormat(r'$#,##0.00');
    final rows = <(String, int, double)>[
      ('Widget', 1200, 2.50),
      ('Gadget', 340, 9.99),
      ('Gizmo', 55, 49.00),
    ];
    for (var i = 0; i < rows.length; i++) {
      final row = i + 2;
      final (name, units, price) = rows[i];
      sheet.writeString(row, 0, name);
      sheet.writeNumber(row, 1, units);
      sheet.writeNumber(row, 2, price, currency);
      // Total as a live formula. libxlsxwriter stores the formula text; Excel
      // computes the value when the file is opened. Cell references are
      // 1-based in formulas but the row and col arguments are 0-based, hence
      // the `+ 1`.
      sheet.writeFormula(row, 3, '=B${row + 1}*C${row + 1}', currency);
    }

    // A date column, which needs a date number format — without one Excel
    // shows the underlying serial number instead of a date.
    final dateFormat = workbook.addFormat()..numberFormat('yyyy-mm-dd');
    sheet.writeString(6, 0, 'Report date');
    sheet.writeDateTime(6, 1, DateTime(2026, 7, 17), dateFormat);

    // Widths and a frozen header.
    sheet.setColumn(0, 0, 16);
    sheet.setColumn(1, 3, 12);
    sheet.freezePanes(2, 0);

    // A column chart of units sold by item, plotting the data written above.
    // Ranges reference the sheet by name, so a chart can read data from any
    // sheet in the workbook.
    final chart = workbook.addChart(ChartType.column)
      ..setTitle('Units sold')
      ..setAxisNames(category: 'Item', value: 'Units')
      ..addSeries(
        categories: r'=Sales!$A$3:$A$5',
        values: r'=Sales!$B$3:$B$5',
        name: 'Units',
      );
    sheet.insertChart(1, 5, chart);
  } finally {
    // close() is the call that writes the file; without it nothing reaches
    // disk. A try/finally releases the native workbook even on an error.
    workbook.close();
  }

  stdout.writeln('wrote $path');
}
