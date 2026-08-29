// A small report with a column chart and a pie chart: the data table, titles,
// axis names, series names, a moved legend, and pie percentages.
//
// Charts are a reason to reach for a native writer — the pure-Dart writers
// cannot produce them at all. This uses the default `Workbook(...)`, which
// holds the workbook in memory and is the right choice for a report this size.
//
// Run it with `dart run example/chart_report.dart`; it prints the path of the
// file it wrote, for you to open in Excel, Numbers, or LibreOffice.
import 'dart:io';

import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final directory = Directory.systemTemp.createTempSync('xlsxwriter_chart');
  final path = '${directory.path}${Platform.pathSeparator}chart_report.xlsx';

  final workbook = Workbook(path);
  try {
    final sheet = workbook.addWorksheet('Sales');

    final header = workbook.addFormat()
      ..bold()
      ..backgroundColor(0xD9E1F2);
    sheet.writeRow(0, const [
      'Region',
      'Q1',
      'Q2',
      'Q3',
      'Q4',
      'Year',
    ], format: header);

    const rows = <(String, List<int>)>[
      ('East', [120, 140, 90, 175]),
      ('West', [80, 95, 110, 130]),
      ('North', [60, 72, 68, 90]),
    ];
    for (var i = 0; i < rows.length; i++) {
      final (region, quarters) = rows[i];
      final excelRow = i + 1;
      sheet.writeString(excelRow, 0, region);
      for (var q = 0; q < quarters.length; q++) {
        sheet.writeNumber(excelRow, q + 1, quarters[q]);
      }
      sheet.writeNumber(
        excelRow,
        5,
        quarters.fold<int>(0, (sum, n) => sum + n),
      );
    }

    sheet.setColumn(0, 0, 12);
    sheet.setColumn(1, 5, 10);

    // One series per region, plotting the four quarters.
    final column = workbook.addChart(ChartType.column)
      ..setTitle('Units by region')
      ..setAxisNames(category: 'Quarter', value: 'Units')
      ..setLegend(ChartLegendPosition.bottom)
      ..setStyle(10);
    for (var i = 0; i < rows.length; i++) {
      final excelRow = i + 2; // 1-based Excel row of this region
      column.addSeries(
        categories: r'=Sales!$B$1:$E$1',
        values: '=Sales!\$B\$$excelRow:\$E\$$excelRow',
        name: rows[i].$1,
      );
    }
    sheet.insertChart(6, 0, column, xScale: 1.4, yScale: 1.2);

    // Full-year mix as a pie, with percentages on the slices and no legend.
    final pie = workbook.addChart(ChartType.pie)
      ..setTitle('Share of year')
      ..setLegend(ChartLegendPosition.none)
      ..addSeries(
        categories: r'=Sales!$A$2:$A$4',
        values: r'=Sales!$F$2:$F$4',
        name: 'Year',
        labelsPercentage: true,
      );
    sheet.insertChart(6, 8, pie);
  } finally {
    workbook.close();
  }

  stdout.writeln('wrote $path');
}
