import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

import 'xlsx_reader.dart';

void main() {
  late Directory dir;
  setUp(
    () => dir = Directory.systemTemp.createTempSync('xlsxwriter_chart_test'),
  );
  tearDown(() => dir.deleteSync(recursive: true));

  String build(void Function(Workbook wb, Worksheet sheet) fn) {
    final path = '${dir.path}/chart.xlsx';
    final wb = Workbook(path);
    final sheet = wb.addWorksheet('Data');
    fn(wb, sheet);
    wb.close();
    return path;
  }

  test('a column chart is written as a real chart part', () {
    final path = build((wb, sheet) {
      const labels = ['Q1', 'Q2', 'Q3', 'Q4'];
      const revenue = [120, 140, 90, 175];
      for (var i = 0; i < labels.length; i++) {
        sheet.writeString(i, 0, labels[i]);
        sheet.writeNumber(i, 1, revenue[i]);
      }
      final chart = wb.addChart(ChartType.column)
        ..setTitle('Revenue by quarter')
        ..setAxisNames(category: 'Quarter', value: 'USD (000s)')
        ..addSeries(
          categories: r'=Data!$A$1:$A$4',
          values: r'=Data!$B$1:$B$4',
          name: '2026',
        );
      sheet.insertChart(0, 3, chart);
    });

    final xlsx = XlsxFile.read(path);
    // A chart part and the drawing that anchors it were both emitted.
    expect(xlsx.hasMember('xl/charts/chart1.xml'), isTrue);
    expect(xlsx.hasMember('xl/drawings/drawing1.xml'), isTrue);

    final chartXml = xlsx.text('xl/charts/chart1.xml');
    // A column chart is a bar chart with a column direction in the XML.
    expect(chartXml, contains('barChart'));
    expect(chartXml, contains('<c:barDir val="col"/>'));
    // Title, both axis names, the series name and its value range all made it.
    expect(chartXml, contains('Revenue by quarter'));
    expect(chartXml, contains('Quarter'));
    expect(chartXml, contains('USD (000s)'));
    expect(chartXml, contains('2026'));
    expect(chartXml, contains(r'Data!$B$1:$B$4'));

    // The worksheet references the drawing that holds the chart.
    expect(xlsx.text('xl/worksheets/sheet1.xml'), contains('<drawing'));
  });

  test('each chart type maps to the matching Excel chart element', () {
    for (final entry in const [
      (ChartType.bar, 'barChart'),
      (ChartType.line, 'lineChart'),
      (ChartType.pie, 'pieChart'),
      (ChartType.area, 'areaChart'),
      (ChartType.doughnut, 'doughnutChart'),
      (ChartType.scatter, 'scatterChart'),
    ]) {
      final type = entry.$1;
      final marker = entry.$2;
      final path = build((wb, sheet) {
        sheet.writeNumber(0, 0, 1);
        sheet.writeNumber(1, 0, 2);
        sheet.writeNumber(0, 1, 3);
        sheet.writeNumber(1, 1, 4);
        final chart = wb.addChart(type);
        // Scatter needs both an x (categories) and y range.
        if (type == ChartType.scatter) {
          chart.addSeries(
            categories: r'=Data!$A$1:$A$2',
            values: r'=Data!$B$1:$B$2',
          );
        } else {
          chart.addSeries(values: r'=Data!$A$1:$A$2');
        }
        sheet.insertChart(0, 3, chart);
      });
      final chartXml = XlsxFile.read(path).text('xl/charts/chart1.xml');
      expect(chartXml, contains(marker), reason: 'chart type $type');
    }
  });

  test('a chart used after the workbook is closed throws', () {
    final path = '${dir.path}/closed.xlsx';
    final wb = Workbook(path);
    wb.addWorksheet('Data');
    final chart = wb.addChart(ChartType.column);
    wb.close();
    expect(() => chart.addSeries(values: r'=Data!$A$1:$A$2'), throwsStateError);
  });
}
