# xlsxwriter example

`xlsxwriter_example.dart` writes a small but complete report to
`example_report.xlsx`, touching most of the API in one file: a bold, colored
title merged across the table, formatted headers, number and currency columns,
a total as a live `SUM` formula, a date column with a date format, column widths
and a frozen header row, and a column chart plotting the data written above.

```dart
final workbook = Workbook('example_report.xlsx');
final sheet = workbook.addWorksheet('Sales');

final title = workbook.addFormat()
  ..bold()
  ..fontColor(0xFFFFFF)
  ..backgroundColor(0x4472C4)
  ..align(HorizontalAlignment.center);
sheet.mergeRange(0, 0, 0, 3, 'Quarterly Sales', title);

sheet.writeRow(1, ['Item', 'Units', 'Price', 'Date'], format: header);
sheet.writeFormula(6, 1, '=SUM(B3:B5)');   // a live total
sheet.freezePanes(2, 0);                    // keep the header visible

workbook.close();                           // flushes the .xlsx to disk
```

Run it:

```
dart run example/xlsxwriter_example.dart
```

It writes `example_report.xlsx` in the current directory — open it in Excel,
Numbers, or LibreOffice. There is no console output; the file is the result.

Note the enum names: `HorizontalAlignment` and `CellBorder` (renamed from
`Alignment`/`Border` in 0.9.0 so they don't clash with Flutter's own types when
you write a spreadsheet from a Flutter app).
