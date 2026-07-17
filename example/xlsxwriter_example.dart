// A small tour of the xlsxwriter API: formatted headers, several data types,
// a formula, a date, a merged title, frozen panes, and column widths.
//
// Run it with `dart run example/xlsxwriter_example.dart`; it writes
// `example_report.xlsx` in the current directory.
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final workbook = Workbook('example_report.xlsx');
  final sheet = workbook.addWorksheet('Sales');

  // A bold, colored, centered title merged across the table width.
  final title = workbook.addFormat()
    ..bold()
    ..fontSize(14)
    ..fontColor(0xFFFFFF)
    ..backgroundColor(0x4472C4)
    ..align(Alignment.center)
    ..verticalAlign(VerticalAlignment.center);
  sheet.mergeRange(0, 0, 0, 3, 'Quarterly Sales', title);
  sheet.setRow(0, 24);

  // Column headers.
  final header = workbook.addFormat()
    ..bold()
    ..border(Border.thin)
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
    // Total as a live formula.
    sheet.writeFormula(row, 3, '=B${row + 1}*C${row + 1}', currency);
  }

  // A date column, which needs a date number format.
  final dateFormat = workbook.addFormat()..numberFormat('yyyy-mm-dd');
  sheet.writeString(6, 0, 'Report date');
  sheet.writeDateTime(6, 1, DateTime(2026, 7, 17), dateFormat);

  // Widths, a frozen header, and we are done.
  sheet.setColumn(0, 0, 16);
  sheet.setColumn(1, 3, 12);
  sheet.freezePanes(2, 0);

  workbook.close();
}
