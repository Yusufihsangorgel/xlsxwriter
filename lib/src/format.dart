part of 'workbook.dart';

/// Cell formatting, obtained from [Workbook.addFormat].
///
/// Every setter returns the same [Format] so calls can be chained:
///
/// ```dart
/// final header = workbook.addFormat()
///   ..bold()
///   ..fontColor(0xFFFFFF)
///   ..backgroundColor(0x4472C4)
///   ..align(Alignment.center);
/// ```
///
/// Colors are 24-bit RGB integers, `0xRRGGBB` (for example `0xFF0000` is red).
/// A single format may be applied to any number of cells. A format is valid
/// only until its workbook is closed.
class Format {
  Format._(this._workbook, this._handle);

  final Workbook _workbook;
  final Pointer<Void> _handle;

  /// Makes the font bold.
  Format bold() {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetBold(_handle);
    return this;
  }

  /// Makes the font italic.
  Format italic() {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetItalic(_handle);
    return this;
  }

  /// Underlines the font with [style], single underline by default.
  Format underline([Underline style = Underline.single]) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetUnderline(_handle, style.value);
    return this;
  }

  /// Sets the font [name], for example `'Calibri'` or `'Courier New'`.
  Format fontName(String name) {
    _workbook._ensureOpen();
    final cName = name.toNativeUtf8();
    try {
      bindings.xlsxwFormatSetFontName(_handle, cName);
    } finally {
      malloc.free(cName);
    }
    return this;
  }

  /// Sets the font [size] in points.
  Format fontSize(double size) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetFontSize(_handle, size);
    return this;
  }

  /// Sets the font color to the 24-bit RGB value [rgb] (`0xRRGGBB`).
  Format fontColor(int rgb) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetFontColor(_handle, rgb);
    return this;
  }

  /// Sets the cell background (fill) color to the 24-bit RGB value [rgb]
  /// (`0xRRGGBB`).
  Format backgroundColor(int rgb) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetBgColor(_handle, rgb);
    return this;
  }

  /// Sets the Excel number format string [numberFormat], for example
  /// `'0.00'`, `'#,##0'`, `'0%'`, or a date format such as `'yyyy-mm-dd'`.
  Format numberFormat(String numberFormat) {
    _workbook._ensureOpen();
    final cValue = numberFormat.toNativeUtf8();
    try {
      bindings.xlsxwFormatSetNumFormat(_handle, cValue);
    } finally {
      malloc.free(cValue);
    }
    return this;
  }

  /// Sets the horizontal [alignment].
  Format align(Alignment alignment) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetAlign(_handle, alignment.value);
    return this;
  }

  /// Sets the vertical [alignment].
  Format verticalAlign(VerticalAlignment alignment) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetAlign(_handle, alignment.value);
    return this;
  }

  /// Wraps long text onto multiple lines within the cell.
  Format textWrap() {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetTextWrap(_handle);
    return this;
  }

  /// Draws a border on all four sides of the cell with [style], a thin border
  /// by default.
  Format border([Border style = Border.thin]) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetBorder(_handle, style.value);
    return this;
  }

  /// Sets the border color to the 24-bit RGB value [rgb] (`0xRRGGBB`).
  Format borderColor(int rgb) {
    _workbook._ensureOpen();
    bindings.xlsxwFormatSetBorderColor(_handle, rgb);
    return this;
  }
}
