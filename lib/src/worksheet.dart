part of 'workbook.dart';

/// A single sheet within a [Workbook], obtained from [Workbook.addWorksheet].
///
/// All positions are 0-based: row `0`, column `0` is cell `A1`. A worksheet is
/// valid only until its workbook is closed; using it afterwards throws a
/// [StateError].
class Worksheet {
  Worksheet._(this._workbook, this._handle);

  final Workbook _workbook;
  final Pointer<Void> _handle;

  /// Writes the string [value] to the cell at [row], [col].
  ///
  /// An empty string writes an empty (but formatted, if [format] is given)
  /// cell. Strings longer than Excel's limit of 32,767 characters throw an
  /// [XlsxWriterException].
  void writeString(int row, int col, String value, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    final cValue = value.toNativeUtf8();
    try {
      _check(
        bindings.xlsxwWriteString(
          _handle,
          row,
          col,
          cValue,
          _formatHandle(format),
        ),
      );
    } finally {
      malloc.free(cValue);
    }
  }

  /// Writes the number [value] to the cell at [row], [col].
  ///
  /// Both integers and doubles are stored as Excel numbers (Excel has a single
  /// numeric type). Use a [format] with a [Format.numberFormat] to control how
  /// the value is displayed.
  void writeNumber(int row, int col, num value, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    _check(
      bindings.xlsxwWriteNumber(
        _handle,
        row,
        col,
        value.toDouble(),
        _formatHandle(format),
      ),
    );
  }

  /// Writes the boolean [value] to the cell at [row], [col].
  void writeBool(int row, int col, bool value, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    _check(
      bindings.xlsxwWriteBoolean(
        _handle,
        row,
        col,
        value ? 1 : 0,
        _formatHandle(format),
      ),
    );
  }

  /// Writes a [formula] to the cell at [row], [col].
  ///
  /// The formula is given in the usual Excel form with a leading `=`, for
  /// example `'=SUM(A1:A10)'`. libxlsxwriter stores the formula; Excel
  /// computes the cached result when the file is opened.
  void writeFormula(int row, int col, String formula, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    final cFormula = formula.toNativeUtf8();
    try {
      _check(
        bindings.xlsxwWriteFormula(
          _handle,
          row,
          col,
          cFormula,
          _formatHandle(format),
        ),
      );
    } finally {
      malloc.free(cFormula);
    }
  }

  /// Writes the [value] as a date/time to the cell at [row], [col].
  ///
  /// Excel stores dates as numbers, so a [format] carrying a date
  /// [Format.numberFormat] (such as `'yyyy-mm-dd'`) is required for the cell to
  /// display as a date rather than a serial number. The sub-second part of
  /// [value] is written to millisecond resolution.
  void writeDateTime(int row, int col, DateTime value, Format format) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    final seconds = value.second + value.millisecond / 1000.0;
    _check(
      bindings.xlsxwWriteDatetime(
        _handle,
        row,
        col,
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        seconds,
        format._handle,
      ),
    );
  }

  /// Writes a hyperlink [url] to the cell at [row], [col].
  ///
  /// The URL is also used as the display text. Supported schemes include
  /// `http`, `https`, `ftp`, `mailto`, and libxlsxwriter's `internal:` and
  /// `external:` links. URLs longer than Excel's limit of 2,079 characters
  /// throw an [XlsxWriterException].
  void writeUrl(int row, int col, String url, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    final cUrl = url.toNativeUtf8();
    try {
      _check(
        bindings.xlsxwWriteUrl(_handle, row, col, cUrl, _formatHandle(format)),
      );
    } finally {
      malloc.free(cUrl);
    }
  }

  /// Writes a blank but formatted cell at [row], [col].
  ///
  /// Excel distinguishes an empty cell from a blank cell that carries
  /// formatting. libxlsxwriter records a blank cell only when a [format] is
  /// supplied; with no format the call has no effect.
  void writeBlank(int row, int col, [Format? format]) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    _check(bindings.xlsxwWriteBlank(_handle, row, col, _formatHandle(format)));
  }

  /// Writes a whole row of [values] starting at [startCol], dispatching each by
  /// its runtime type: a `String` writes a string cell, an `int` or `double` a
  /// number, a `bool` a boolean, a `DateTime` a date, and `null` a blank cell.
  ///
  /// This is the shape a report or an export usually has, a list per row, so it
  /// saves picking the right `write...` per column by hand. [format] applies to
  /// the string, number, boolean and blank cells. A `DateTime` needs a number
  /// format to render as a date rather than a raw serial, so [dateFormat] is
  /// required if [values] contains one; a `DateTime` with no [dateFormat] is a
  /// [ArgumentError]. A value of any other type is also an [ArgumentError],
  /// naming the offending column, rather than being silently coerced.
  ///
  /// ```dart
  /// final date = workbook.addFormat().numberFormat('yyyy-mm-dd');
  /// sheet.writeRow(0, ['Widget', 12, 4.99, DateTime(2026, 7, 20)],
  ///     dateFormat: date);
  /// ```
  void writeRow(
    int row,
    List<Object?> values, {
    int startCol = 0,
    Format? format,
    Format? dateFormat,
  }) {
    for (var i = 0; i < values.length; i++) {
      final col = startCol + i;
      final value = values[i];
      switch (value) {
        case null:
          writeBlank(row, col, format);
        case final String s:
          writeString(row, col, s, format);
        case final bool b:
          writeBool(row, col, b, format);
        case final num n:
          writeNumber(row, col, n, format);
        case final DateTime d:
          if (dateFormat == null) {
            throw ArgumentError.value(
              value,
              'values[$i]',
              'a DateTime needs a dateFormat to render as a date',
            );
          }
          writeDateTime(row, col, d, dateFormat);
        default:
          throw ArgumentError.value(
            value,
            'values[$i]',
            'unsupported cell type ${value.runtimeType} in column $col',
          );
      }
    }
  }

  /// Sets the width, and optionally a default [format], for the columns from
  /// [firstCol] to [lastCol] inclusive.
  ///
  /// [width] is in Excel's column-width units (roughly the count of `0`
  /// characters of the default font that fit in the column).
  void setColumn(int firstCol, int lastCol, double width, [Format? format]) {
    _workbook._ensureOpen();
    if (firstCol < 0 || lastCol < 0) {
      throw ArgumentError('Column indices must be greater than or equal to 0.');
    }
    _check(
      bindings.xlsxwSetColumn(
        _handle,
        firstCol,
        lastCol,
        width,
        _formatHandle(format),
      ),
    );
  }

  /// Sets the [width] of a single column [col]. A convenience wrapper over
  /// [setColumn] with `firstCol == lastCol`.
  void setColumnWidth(int col, double width) => setColumn(col, col, width);

  /// Sets the [height] in points, and optionally a default [format], for a
  /// single [row].
  void setRow(int row, double height, [Format? format]) {
    _workbook._ensureOpen();
    if (row < 0) {
      throw ArgumentError.value(
        row,
        'row',
        'must be greater than or equal to 0',
      );
    }
    _check(bindings.xlsxwSetRow(_handle, row, height, _formatHandle(format)));
  }

  /// Merges the rectangle of cells from ([firstRow], [firstCol]) to
  /// ([lastRow], [lastCol]) inclusive and writes [value] into it.
  ///
  /// A [format] is normally supplied, since Excel applies the merge's
  /// formatting from the top-left cell. The range must span more than one
  /// cell.
  void mergeRange(
    int firstRow,
    int firstCol,
    int lastRow,
    int lastCol,
    String value, [
    Format? format,
  ]) {
    _workbook._ensureOpen();
    _validateCell(firstRow, firstCol);
    _validateCell(lastRow, lastCol);
    final cValue = value.toNativeUtf8();
    try {
      _check(
        bindings.xlsxwMergeRange(
          _handle,
          firstRow,
          firstCol,
          lastRow,
          lastCol,
          cValue,
          _formatHandle(format),
        ),
      );
    } finally {
      malloc.free(cValue);
    }
  }

  /// Freezes rows above [row] and columns to the left of [col], keeping them
  /// visible while the rest of the sheet scrolls.
  ///
  /// For example `freezePanes(1, 0)` freezes the first row and
  /// `freezePanes(1, 1)` freezes the first row and the first column. Passing
  /// `(0, 0)` removes any frozen panes.
  void freezePanes(int row, int col) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    bindings.xlsxwFreezePanes(_handle, row, col);
  }

  /// Adds a formatted table over the range from ([firstRow], [firstCol]) to
  /// ([lastRow], [lastCol]).
  ///
  /// A table gives the range banded rows, a filter dropdown on each column, and
  /// a name you can reference in formulas, which is the shape most "export to
  /// Excel" output wants.
  ///
  /// [columns] names the table's columns, one per column in the range, and the
  /// names are written into the header row for you. If it is null the columns
  /// are named `Column1`, `Column2`, and so on; note that Excel writes those
  /// default names over the header cells, so pass [columns] whenever the header
  /// matters. Set [headerRow] to false to treat the whole range as data with no
  /// header.
  ///
  /// [name] names the table; Excel requires the name to be unique in the
  /// workbook and to start with a letter. Pass null for an auto-generated name.
  /// [autofilter] toggles the per-column filter dropdowns, [bandedRows] and
  /// [bandedColumns] the alternating stripes, and [totalRow] adds a totals row
  /// at the bottom of the range.
  ///
  /// Throws an [ArgumentError] if [columns] is given but its length does not
  /// match the number of columns in the range, a [RangeError] if a coordinate
  /// is out of range, and an [XlsxWriterException] if the native call fails.
  void addTable(
    int firstRow,
    int firstCol,
    int lastRow,
    int lastCol, {
    String? name,
    List<String>? columns,
    bool headerRow = true,
    bool autofilter = true,
    bool bandedRows = true,
    bool bandedColumns = false,
    bool totalRow = false,
  }) {
    _workbook._ensureOpen();
    _validateCell(firstRow, firstCol);
    _validateCell(lastRow, lastCol);
    final rangeColumns = lastCol - firstCol + 1;
    if (columns != null && columns.length != rangeColumns) {
      throw ArgumentError.value(
        columns.length,
        'columns',
        'must have one name per column in the range ($rangeColumns)',
      );
    }

    final cName = (name ?? '').toNativeUtf8();
    final headerPtrs = columns == null
        ? nullptr
        : malloc.allocate<Pointer<Utf8>>(sizeOf<Pointer<Utf8>>() * columns.length);
    try {
      if (columns != null) {
        for (var i = 0; i < columns.length; i++) {
          headerPtrs[i] = columns[i].toNativeUtf8();
        }
      }
      _check(
        bindings.xlsxwAddTable(
          _handle,
          firstRow,
          firstCol,
          lastRow,
          lastCol,
          cName,
          headerPtrs,
          columns?.length ?? 0,
          headerRow ? 0 : 1,
          autofilter ? 0 : 1,
          bandedRows ? 0 : 1,
          bandedColumns ? 1 : 0,
          totalRow ? 1 : 0,
          0, // default built-in table style
        ),
      );
    } finally {
      if (columns != null) {
        for (var i = 0; i < columns.length; i++) {
          malloc.free(headerPtrs[i]);
        }
        malloc.free(headerPtrs);
      }
      malloc.free(cName);
    }
  }

  /// Places [chart] on this sheet with its top-left corner at ([row], [col]).
  ///
  /// Build the chart first with [Workbook.addChart] and [Chart.addSeries]; a
  /// chart with no series has nothing to draw. [xScale] and [yScale] scale the
  /// chart from its natural size (1.0), so `xScale: 2.0` draws it twice as
  /// wide. The chart's data series reference cells by formula, so the data can
  /// live on this sheet or another one.
  ///
  /// Throws a [RangeError] if the anchor is out of range and an
  /// [XlsxWriterException] if the native call fails.
  void insertChart(
    int row,
    int col,
    Chart chart, {
    double xScale = 1.0,
    double yScale = 1.0,
  }) {
    _workbook._ensureOpen();
    _validateCell(row, col);
    _check(
      bindings.xlsxwInsertChart(_handle, row, col, chart._handle, xScale, yScale),
    );
  }
}
