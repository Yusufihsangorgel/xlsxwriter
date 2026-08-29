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

  test('a column chart is written as a real, well-formed chart part', () {
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

    // Parsing is the well-formedness check: XmlDocument.parse throws if the
    // chart XML is not well-formed.
    final chartDoc = xlsx.xml('xl/charts/chart1.xml');
    expect(chartDoc.rootElement.name.local, 'chartSpace');

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
      (ChartType.radar, 'radarChart'),
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
      final xlsx = XlsxFile.read(path);
      final chartDoc = xlsx.xml('xl/charts/chart1.xml');
      expect(chartDoc.rootElement.name.local, 'chartSpace');
      expect(
        xlsx.text('xl/charts/chart1.xml'),
        contains(marker),
        reason: 'chart type $type',
      );
    }
  });

  test('a stacked column chart writes stacked grouping', () {
    final path = build((wb, sheet) {
      sheet.writeString(0, 0, 'Q1');
      sheet.writeNumber(0, 1, 10);
      sheet.writeNumber(0, 2, 4);
      sheet.writeString(1, 0, 'Q2');
      sheet.writeNumber(1, 1, 12);
      sheet.writeNumber(1, 2, 5);
      final chart = wb.addChart(ChartType.columnStacked)
        ..addSeries(
          categories: r'=Data!$A$1:$A$2',
          values: r'=Data!$B$1:$B$2',
          name: 'East',
        )
        ..addSeries(
          categories: r'=Data!$A$1:$A$2',
          values: r'=Data!$C$1:$C$2',
          name: 'West',
        );
      sheet.insertChart(0, 4, chart);
    });

    final chartXml = XlsxFile.read(path).text('xl/charts/chart1.xml');
    expect(chartXml, contains('barChart'));
    expect(chartXml, contains('<c:barDir val="col"/>'));
    expect(chartXml, contains('<c:grouping val="stacked"/>'));
    expect(chartXml, contains('East'));
    expect(chartXml, contains('West'));
  });

  test('a stacked bar and stacked line write stacked grouping', () {
    for (final entry in const [
      (ChartType.barStacked, 'barChart', 'bar'),
      (ChartType.lineStacked, 'lineChart', null),
    ]) {
      final path = build((wb, sheet) {
        sheet.writeNumber(0, 0, 1);
        sheet.writeNumber(1, 0, 2);
        sheet.writeNumber(0, 1, 3);
        sheet.writeNumber(1, 1, 4);
        final chart = wb.addChart(entry.$1)
          ..addSeries(
            categories: r'=Data!$A$1:$A$2',
            values: r'=Data!$B$1:$B$2',
          );
        sheet.insertChart(0, 3, chart);
      });
      final chartXml = XlsxFile.read(path).text('xl/charts/chart1.xml');
      expect(chartXml, contains(entry.$2), reason: '${entry.$1} element');
      expect(
        chartXml,
        contains('<c:grouping val="stacked"/>'),
        reason: '${entry.$1} grouping',
      );
      if (entry.$3 != null) {
        expect(chartXml, contains('<c:barDir val="${entry.$3}"/>'));
      }
    }
  });

  test('setLegend writes the position, or omits the legend when none', () {
    final bottom = build((wb, sheet) {
      sheet.writeNumber(0, 0, 1);
      sheet.writeNumber(1, 0, 2);
      final chart = wb.addChart(ChartType.column)
        ..addSeries(values: r'=Data!$A$1:$A$2')
        ..setLegend(ChartLegendPosition.bottom);
      sheet.insertChart(0, 3, chart);
    });
    expect(
      XlsxFile.read(bottom).text('xl/charts/chart1.xml'),
      contains('<c:legendPos val="b"/>'),
    );

    final hidden = build((wb, sheet) {
      sheet.writeNumber(0, 0, 1);
      sheet.writeNumber(1, 0, 2);
      final chart = wb.addChart(ChartType.column)
        ..addSeries(values: r'=Data!$A$1:$A$2')
        ..setLegend(ChartLegendPosition.none);
      sheet.insertChart(0, 3, chart);
    });
    expect(
      XlsxFile.read(hidden).text('xl/charts/chart1.xml'),
      isNot(contains('<c:legend')),
    );
  });

  test('setStyle writes a non-default style id', () {
    final path = build((wb, sheet) {
      sheet.writeNumber(0, 0, 1);
      sheet.writeNumber(1, 0, 2);
      final chart = wb.addChart(ChartType.column)
        ..addSeries(values: r'=Data!$A$1:$A$2')
        ..setStyle(10);
      sheet.insertChart(0, 3, chart);
    });
    expect(
      XlsxFile.read(path).text('xl/charts/chart1.xml'),
      contains('<c:style val="10"/>'),
    );
  });

  test('setStyle rejects an id outside 1..48', () {
    final path = '${dir.path}/style.xlsx';
    final wb = Workbook(path);
    wb.addWorksheet('Data');
    final chart = wb.addChart(ChartType.column);
    expect(() => chart.setStyle(0), throwsArgumentError);
    expect(() => chart.setStyle(49), throwsArgumentError);
    wb.close();
  });

  test('pie data labels write dLbls and showPercent', () {
    final path = build((wb, sheet) {
      sheet.writeString(0, 0, 'East');
      sheet.writeNumber(0, 1, 40);
      sheet.writeString(1, 0, 'West');
      sheet.writeNumber(1, 1, 60);
      final chart = wb.addChart(ChartType.pie)
        ..setTitle('Share')
        ..setLegend(ChartLegendPosition.none)
        ..addSeries(
          categories: r'=Data!$A$1:$A$2',
          values: r'=Data!$B$1:$B$2',
          name: 'Share',
          labelsPercentage: true,
        );
      sheet.insertChart(0, 3, chart);
    });

    final xlsx = XlsxFile.read(path);
    final chartDoc = xlsx.xml('xl/charts/chart1.xml');
    expect(chartDoc.rootElement.name.local, 'chartSpace');
    final chartXml = xlsx.text('xl/charts/chart1.xml');
    expect(chartXml, contains('pieChart'));
    expect(chartXml, contains('Share'));
    expect(chartXml, contains('<c:dLbls>'));
    expect(chartXml, contains('showPercent'));
  });

  test('a chart used after the workbook is closed throws', () {
    final path = '${dir.path}/closed.xlsx';
    final wb = Workbook(path);
    wb.addWorksheet('Data');
    final chart = wb.addChart(ChartType.column);
    wb.close();
    expect(() => chart.addSeries(values: r'=Data!$A$1:$A$2'), throwsStateError);
    expect(() => chart.setTitle('x'), throwsStateError);
    expect(() => chart.setLegend(ChartLegendPosition.bottom), throwsStateError);
    expect(() => chart.setStyle(3), throwsStateError);
  });
}
