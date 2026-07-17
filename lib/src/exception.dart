import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart' as bindings;

/// Thrown when libxlsxwriter reports an error.
///
/// [code] is the underlying `lxw_error` value and [message] is
/// libxlsxwriter's human-readable description of it, as returned by
/// `lxw_strerror`.
class XlsxWriterException implements Exception {
  /// Creates an exception for the given libxlsxwriter [code].
  XlsxWriterException(this.code) : message = _messageFor(code);

  /// The underlying `lxw_error` enum value. `0` means no error and is never
  /// used to build an exception.
  final int code;

  /// The human-readable description of [code].
  final String message;

  static String _messageFor(int code) {
    final pointer = bindings.xlsxwStrerror(code);
    if (pointer == nullptr) return 'Unknown error ($code)';
    return pointer.toDartString();
  }

  @override
  String toString() => 'XlsxWriterException($code): $message';
}
