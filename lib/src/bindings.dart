import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Bindings to the C ABI shim over libxlsxwriter. The native library is produced
// by hook/build.dart, which registers it under the asset id of this library
// (src/bindings.dart), so every @Native symbol below resolves to it. Every
// symbol is one of the `xlsxw_*` wrappers, each marked exported on Windows, so
// lookup succeeds there as well as on macOS and Linux.
//
// Handles (workbook, worksheet, format) are opaque `Pointer<Void>`. Cell and
// layout functions return an int that is a value of libxlsxwriter's `lxw_error`
// enum: 0 is success, anything else is described by [xlsxwStrerror]. This
// library is not exported; it is the private implementation of the public API.

// Selected `lxw_error` values, used to build an [XlsxWriterException] on the
// paths where libxlsxwriter reports failure by returning a null handle rather
// than an error code. These enumerator values are part of libxlsxwriter's
// stable public API.

/// `LXW_ERROR_MEMORY_MALLOC_FAILED`: a required allocation failed.
const int lxwErrorMemoryMallocFailed = 1;

/// `LXW_ERROR_CREATING_XLSX_FILE`: the output file could not be created
/// (usually a permissions error).
const int lxwErrorCreatingXlsxFile = 2;

/// `LXW_ERROR_PARAMETER_VALIDATION`: a parameter failed validation (for
/// example an invalid or duplicate worksheet name).
const int lxwErrorParameterValidation = 13;

/// Creates a workbook that buffers in memory and writes on close.
@Native<Pointer<Void> Function(Pointer<Utf8>)>(symbol: 'xlsxw_workbook_new')
external Pointer<Void> xlsxwWorkbookNew(Pointer<Utf8> filename);

/// Creates a workbook in constant-memory mode (rows are flushed to a temp file
/// as they are written).
@Native<Pointer<Void> Function(Pointer<Utf8>)>(
  symbol: 'xlsxw_workbook_new_constant_memory',
)
external Pointer<Void> xlsxwWorkbookNewConstantMemory(Pointer<Utf8> filename);

/// Adds a worksheet. [name] may be `nullptr` for the default `SheetN`.
@Native<Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>)>(
  symbol: 'xlsxw_add_worksheet',
)
external Pointer<Void> xlsxwAddWorksheet(
  Pointer<Void> workbook,
  Pointer<Utf8> name,
);

/// Adds a format handle owned by the workbook.
@Native<Pointer<Void> Function(Pointer<Void>)>(symbol: 'xlsxw_add_format')
external Pointer<Void> xlsxwAddFormat(Pointer<Void> workbook);

/// Writes the file and frees the workbook. Returns an `lxw_error` value.
@Native<Int32 Function(Pointer<Void>)>(symbol: 'xlsxw_close')
external int xlsxwClose(Pointer<Void> workbook);

/// Frees a workbook without writing it. Used only by the finalizer.
@Native<Void Function(Pointer<Void>)>(symbol: 'xlsxw_workbook_free')
external void xlsxwWorkbookFree(Pointer<Void> workbook);

/// Writes the string [value] to the cell at [row], [col].
@Native<
  Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Utf8>, Pointer<Void>)
>(symbol: 'xlsxw_write_string')
external int xlsxwWriteString(
  Pointer<Void> worksheet,
  int row,
  int col,
  Pointer<Utf8> value,
  Pointer<Void> format,
);

/// Writes the number [value] to the cell at [row], [col].
@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Double, Pointer<Void>)>(
  symbol: 'xlsxw_write_number',
)
external int xlsxwWriteNumber(
  Pointer<Void> worksheet,
  int row,
  int col,
  double value,
  Pointer<Void> format,
);

/// Writes the boolean [value] (0 or 1) to the cell at [row], [col].
@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Int32, Pointer<Void>)>(
  symbol: 'xlsxw_write_boolean',
)
external int xlsxwWriteBoolean(
  Pointer<Void> worksheet,
  int row,
  int col,
  int value,
  Pointer<Void> format,
);

/// Writes the [formula] to the cell at [row], [col].
@Native<
  Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Utf8>, Pointer<Void>)
>(symbol: 'xlsxw_write_formula')
external int xlsxwWriteFormula(
  Pointer<Void> worksheet,
  int row,
  int col,
  Pointer<Utf8> formula,
  Pointer<Void> format,
);

/// Writes the date/time (given as its components) to the cell at [row], [col].
@Native<
  Int32 Function(
    Pointer<Void>,
    Uint32,
    Uint32,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Double,
    Pointer<Void>,
  )
>(symbol: 'xlsxw_write_datetime')
external int xlsxwWriteDatetime(
  Pointer<Void> worksheet,
  int row,
  int col,
  int year,
  int month,
  int day,
  int hour,
  int min,
  double sec,
  Pointer<Void> format,
);

/// Writes the hyperlink [url] to the cell at [row], [col].
@Native<
  Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Utf8>, Pointer<Void>)
>(symbol: 'xlsxw_write_url')
external int xlsxwWriteUrl(
  Pointer<Void> worksheet,
  int row,
  int col,
  Pointer<Utf8> url,
  Pointer<Void> format,
);

/// Writes a blank, [format]-carrying cell at [row], [col].
@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Void>)>(
  symbol: 'xlsxw_write_blank',
)
external int xlsxwWriteBlank(
  Pointer<Void> worksheet,
  int row,
  int col,
  Pointer<Void> format,
);

/// Sets the [width] and optional [format] for columns [firstCol]..[lastCol].
@Native<Int32 Function(Pointer<Void>, Uint32, Uint32, Double, Pointer<Void>)>(
  symbol: 'xlsxw_set_column',
)
external int xlsxwSetColumn(
  Pointer<Void> worksheet,
  int firstCol,
  int lastCol,
  double width,
  Pointer<Void> format,
);

/// Sets the [height] and optional [format] for a single [row].
@Native<Int32 Function(Pointer<Void>, Uint32, Double, Pointer<Void>)>(
  symbol: 'xlsxw_set_row',
)
external int xlsxwSetRow(
  Pointer<Void> worksheet,
  int row,
  double height,
  Pointer<Void> format,
);

/// Merges a rectangle of cells and writes [value] into it.
@Native<
  Int32 Function(
    Pointer<Void>,
    Uint32,
    Uint32,
    Uint32,
    Uint32,
    Pointer<Utf8>,
    Pointer<Void>,
  )
>(symbol: 'xlsxw_merge_range')
external int xlsxwMergeRange(
  Pointer<Void> worksheet,
  int firstRow,
  int firstCol,
  int lastRow,
  int lastCol,
  Pointer<Utf8> value,
  Pointer<Void> format,
);

/// Freezes panes above [row] and left of [col].
@Native<Void Function(Pointer<Void>, Uint32, Uint32)>(
  symbol: 'xlsxw_freeze_panes',
)
external void xlsxwFreezePanes(Pointer<Void> worksheet, int row, int col);

/// Makes the format's font bold.
@Native<Void Function(Pointer<Void>)>(symbol: 'xlsxw_format_set_bold')
external void xlsxwFormatSetBold(Pointer<Void> format);

/// Makes the format's font italic.
@Native<Void Function(Pointer<Void>)>(symbol: 'xlsxw_format_set_italic')
external void xlsxwFormatSetItalic(Pointer<Void> format);

/// Sets the format's underline [style].
@Native<Void Function(Pointer<Void>, Int32)>(
  symbol: 'xlsxw_format_set_underline',
)
external void xlsxwFormatSetUnderline(Pointer<Void> format, int style);

/// Sets the format's font [name].
@Native<Void Function(Pointer<Void>, Pointer<Utf8>)>(
  symbol: 'xlsxw_format_set_font_name',
)
external void xlsxwFormatSetFontName(Pointer<Void> format, Pointer<Utf8> name);

/// Sets the format's font [size] in points.
@Native<Void Function(Pointer<Void>, Double)>(
  symbol: 'xlsxw_format_set_font_size',
)
external void xlsxwFormatSetFontSize(Pointer<Void> format, double size);

/// Sets the format's font [color] as an RGB integer.
@Native<Void Function(Pointer<Void>, Int32)>(
  symbol: 'xlsxw_format_set_font_color',
)
external void xlsxwFormatSetFontColor(Pointer<Void> format, int color);

/// Sets the format's background fill [color] as an RGB integer.
@Native<Void Function(Pointer<Void>, Int32)>(
  symbol: 'xlsxw_format_set_bg_color',
)
external void xlsxwFormatSetBgColor(Pointer<Void> format, int color);

/// Sets the format's number-format string [value].
@Native<Void Function(Pointer<Void>, Pointer<Utf8>)>(
  symbol: 'xlsxw_format_set_num_format',
)
external void xlsxwFormatSetNumFormat(
  Pointer<Void> format,
  Pointer<Utf8> value,
);

/// Sets the format's horizontal or vertical [alignment] enum value.
@Native<Void Function(Pointer<Void>, Int32)>(symbol: 'xlsxw_format_set_align')
external void xlsxwFormatSetAlign(Pointer<Void> format, int alignment);

/// Enables text wrapping on the format.
@Native<Void Function(Pointer<Void>)>(symbol: 'xlsxw_format_set_text_wrap')
external void xlsxwFormatSetTextWrap(Pointer<Void> format);

/// Sets the format's border [style] on all four sides.
@Native<Void Function(Pointer<Void>, Int32)>(symbol: 'xlsxw_format_set_border')
external void xlsxwFormatSetBorder(Pointer<Void> format, int style);

/// Sets the format's border [color] as an RGB integer.
@Native<Void Function(Pointer<Void>, Int32)>(
  symbol: 'xlsxw_format_set_border_color',
)
external void xlsxwFormatSetBorderColor(Pointer<Void> format, int color);

/// The human-readable message for an `lxw_error` value. Static storage in the
/// native library; must not be freed.
@Native<Pointer<Utf8> Function(Int32)>(symbol: 'xlsxw_strerror')
external Pointer<Utf8> xlsxwStrerror(int errorCode);

/// Adds a formatted table over a cell range. The flags are booleans (0 or 1);
/// [name] may be an empty string for an auto-generated table name. [headers]
/// is an array of [numColumns] column-header C strings, or [nullptr] with
/// [numColumns] 0 to use libxlsxwriter's default column names.
@Native<
  Int32 Function(
    Pointer<Void>,
    Uint32,
    Uint32,
    Uint32,
    Uint32,
    Pointer<Utf8>,
    Pointer<Pointer<Utf8>>,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
    Int32,
  )
>(symbol: 'xlsxw_add_table')
external int xlsxwAddTable(
  Pointer<Void> worksheet,
  int firstRow,
  int firstCol,
  int lastRow,
  int lastCol,
  Pointer<Utf8> name,
  Pointer<Pointer<Utf8>> headers,
  int numColumns,
  int noHeaderRow,
  int noAutofilter,
  int noBandedRows,
  int bandedColumns,
  int totalRow,
  int styleType,
);

/// Address of the native `xlsxw_workbook_free`, used by a [NativeFinalizer] to
/// reclaim a workbook that was garbage-collected without [xlsxwClose]. It frees
/// memory only and does not write the file.
final Pointer<NativeFinalizerFunction> xlsxwWorkbookFreeFunction =
    Native.addressOf<NativeFinalizerFunction>(xlsxwWorkbookFree);
