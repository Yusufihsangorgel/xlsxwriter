/// A native, fast, low-memory Excel `.xlsx` writer for Dart.
///
/// This library is an FFI binding to
/// [libxlsxwriter](https://github.com/jmcnamara/libxlsxwriter) by John
/// McNamara, compiled from vendored C source at build time. It targets the
/// report- and export-generation use case: writing spreadsheets quickly and
/// with low memory. It does not read existing files; for that use the
/// [`excel`](https://pub.dev/packages/excel) or
/// [`spreadsheet_decoder`](https://pub.dev/packages/spreadsheet_decoder)
/// packages.
///
/// ```dart
/// import 'package:xlsxwriter/xlsxwriter.dart';
///
/// void main() {
///   final workbook = Workbook('report.xlsx');
///   final sheet = workbook.addWorksheet('Summary');
///   final header = workbook.addFormat()..bold();
///   sheet.writeString(0, 0, 'Item', header);
///   sheet.writeString(0, 1, 'Amount', header);
///   sheet.writeString(1, 0, 'Widgets');
///   sheet.writeNumber(1, 1, 1250);
///   workbook.close();
/// }
/// ```
library;

export 'src/enums.dart';
export 'src/exception.dart' show XlsxWriterException;
export 'src/workbook.dart' show Chart, Format, Workbook, Worksheet;
