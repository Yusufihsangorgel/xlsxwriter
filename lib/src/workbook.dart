import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart' as bindings;
import 'enums.dart';
import 'exception.dart';

part 'worksheet.dart';
part 'format.dart';

/// An Excel `.xlsx` workbook, backed by libxlsxwriter.
///
/// A workbook owns its worksheets and formats. Create one, add worksheets and
/// write cells, then call [close] to flush the file to disk:
///
/// ```dart
/// final workbook = Workbook('report.xlsx');
/// final sheet = workbook.addWorksheet('Summary');
/// sheet.writeString(0, 0, 'Item');
/// sheet.writeNumber(0, 1, 42);
/// workbook.close();
/// ```
///
/// Rows and columns are 0-based: `(0, 0)` is cell `A1`, `(1, 2)` is `C2`.
///
/// [close] is what writes the file. A workbook that is garbage-collected
/// without [close] is freed by a [NativeFinalizer] so no memory leaks, but the
/// file is not written. Always call [close] (a `try`/`finally` is a good fit).
class Workbook implements Finalizable {
  /// Opens a workbook that writes to [path] on [close].
  ///
  /// The whole workbook is held in memory until [close]. For very large sheets
  /// prefer [Workbook.constantMemory].
  Workbook(String path) : this._(path, constantMemory: false);

  /// Opens a workbook in constant-memory mode, writing to [path].
  ///
  /// In this mode each row is flushed to a temporary file as soon as the next
  /// row is started, so memory stays roughly flat regardless of sheet size.
  /// This is the mode to use when exporting hundreds of thousands of rows.
  ///
  /// The trade-off is ordering: cells must be written in strict top-to-bottom,
  /// and within a row left-to-right, order. Once you move to a new row the
  /// previous row is on disk and can no longer be modified. Data written out
  /// of order is silently dropped by libxlsxwriter.
  Workbook.constantMemory(String path) : this._(path, constantMemory: true);

  Workbook._(String path, {required bool constantMemory}) {
    final cPath = path.toNativeUtf8();
    try {
      _handle = constantMemory
          ? bindings.xlsxwWorkbookNewConstantMemory(cPath)
          : bindings.xlsxwWorkbookNew(cPath);
    } finally {
      malloc.free(cPath);
    }
    if (_handle == nullptr) {
      throw XlsxWriterException(bindings.lxwErrorCreatingXlsxFile);
    }
    _finalizer.attach(this, _handle, detach: this);
  }

  static final NativeFinalizer _finalizer = NativeFinalizer(
    bindings.xlsxwWorkbookFreeFunction,
  );

  late final Pointer<Void> _handle;
  bool _closed = false;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Adds a worksheet, optionally named [name].
  ///
  /// When [name] is omitted libxlsxwriter assigns the default `Sheet1`,
  /// `Sheet2`, and so on. A name must be 31 characters or fewer, must not
  /// contain any of `[ ] : * ? / \`, and must be unique in the workbook;
  /// otherwise an [XlsxWriterException] is thrown.
  Worksheet addWorksheet([String? name]) {
    _ensureOpen();
    final Pointer<Utf8> cName = name == null ? nullptr : name.toNativeUtf8();
    final Pointer<Void> handle;
    try {
      handle = bindings.xlsxwAddWorksheet(_handle, cName);
    } finally {
      if (cName != nullptr) malloc.free(cName);
    }
    if (handle == nullptr) {
      // libxlsxwriter rejects an invalid or duplicate name by returning null.
      throw XlsxWriterException(bindings.lxwErrorParameterValidation);
    }
    return Worksheet._(this, handle);
  }

  /// Creates a [Format] owned by this workbook.
  ///
  /// Apply it when writing a cell (for example
  /// `sheet.writeString(0, 0, 'Total', workbook.addFormat()..bold())`). The
  /// same format may be reused for any number of cells.
  Format addFormat() {
    _ensureOpen();
    final handle = bindings.xlsxwAddFormat(_handle);
    if (handle == nullptr) {
      throw XlsxWriterException(bindings.lxwErrorMemoryMallocFailed);
    }
    return Format._(this, handle);
  }

  /// Writes the workbook to disk and frees the native resources.
  ///
  /// This is the call that produces the file. It is safe to call more than
  /// once; later calls do nothing. After [close] the workbook and any
  /// worksheets or formats obtained from it must not be used.
  ///
  /// Throws an [XlsxWriterException] if libxlsxwriter fails to write the file
  /// (for example on a permissions error).
  void close() {
    if (_closed) return;
    _closed = true;
    // workbook_close always frees the workbook, even on error, so detach the
    // finalizer before checking the result to avoid a double free.
    _finalizer.detach(this);
    final code = bindings.xlsxwClose(_handle);
    if (code != 0) throw XlsxWriterException(code);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Workbook has been closed.');
    }
  }
}

/// Throws an [XlsxWriterException] when [code] is a non-zero `lxw_error`.
void _check(int code) {
  if (code != 0) throw XlsxWriterException(code);
}

Pointer<Void> _formatHandle(Format? format) =>
    format == null ? nullptr : format._handle;

void _validateCell(int row, int col) {
  if (row < 0) {
    throw ArgumentError.value(row, 'row', 'must be greater than or equal to 0');
  }
  if (col < 0) {
    throw ArgumentError.value(col, 'col', 'must be greater than or equal to 0');
  }
}
