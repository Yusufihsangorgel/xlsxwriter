part of 'workbook.dart';

/// A chart created with [Workbook.addChart] and placed on a sheet with
/// [Worksheet.insertChart].
///
/// A chart is owned by its workbook and freed when the workbook is closed; a
/// [Chart] must not be used after that. Build it by adding one or more data
/// series with [addSeries], then insert it:
///
/// ```dart
/// final chart = workbook.addChart(ChartType.column)
///   ..setTitle('Revenue by quarter')
///   ..addSeries(
///     categories: "=Sheet1!\$A\$2:\$A\$5",
///     values: "=Sheet1!\$B\$2:\$B\$5",
///     name: '2026',
///   );
/// sheet.insertChart(1, 4, chart);
/// ```
///
/// Series ranges are Excel range formulas that reference the sheet holding the
/// data, so they include the sheet name, as in the example above.
class Chart {
  Chart._(this._workbook, this._handle);

  final Workbook _workbook;
  final Pointer<Void> _handle;

  /// Adds a data series plotting [values] against [categories].
  ///
  /// [values] and [categories] are Excel range formulas such as
  /// `"=Sheet1!\$B\$2:\$B\$5"`. [categories] is optional; when omitted the
  /// points are numbered 1..N. [name] sets the series' legend label. Pie and
  /// doughnut charts use only the first series added.
  void addSeries({required String values, String? categories, String? name}) {
    _workbook._ensureOpen();
    _checkNoEmbeddedNul(values, 'values');
    if (categories != null) _checkNoEmbeddedNul(categories, 'categories');
    if (name != null) _checkNoEmbeddedNul(name, 'name');
    final cValues = values.toNativeUtf8();
    final cCategories = categories == null
        ? nullptr
        : categories.toNativeUtf8();
    try {
      final series = bindings.xlsxwChartAddSeries(
        _handle,
        cCategories,
        cValues,
      );
      if (series == nullptr) {
        throw XlsxWriterException(bindings.lxwErrorMemoryMallocFailed);
      }
      if (name != null) {
        final cName = name.toNativeUtf8();
        try {
          bindings.xlsxwChartSeriesSetName(series, cName);
        } finally {
          malloc.free(cName);
        }
      }
    } finally {
      malloc.free(cValues);
      if (cCategories != nullptr) malloc.free(cCategories);
    }
  }

  /// Sets the chart's title, shown above the plot area.
  void setTitle(String title) {
    _workbook._ensureOpen();
    _checkNoEmbeddedNul(title, 'title');
    final cTitle = title.toNativeUtf8();
    try {
      bindings.xlsxwChartTitleSetName(_handle, cTitle);
    } finally {
      malloc.free(cTitle);
    }
  }

  /// Sets the axis titles: [category] labels the horizontal (x) axis and
  /// [value] the vertical (y) axis. Either may be omitted to leave that axis
  /// untitled.
  void setAxisNames({String? category, String? value}) {
    _workbook._ensureOpen();
    if (category != null) _setAxisName(0, category);
    if (value != null) _setAxisName(1, value);
  }

  void _setAxisName(int axis, String name) {
    _checkNoEmbeddedNul(name, 'name');
    final cName = name.toNativeUtf8();
    try {
      bindings.xlsxwChartAxisSetName(_handle, axis, cName);
    } finally {
      malloc.free(cName);
    }
  }
}
