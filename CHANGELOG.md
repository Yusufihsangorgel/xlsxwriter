# Changelog

## 0.1.0

First release. A native `.xlsx` writer for Dart, binding libxlsxwriter 1.2.2
over FFI, with libxlsxwriter and zlib 1.3.1 vendored and compiled from source at
build time (no system dependencies on macOS, Linux, or Windows).

- `Workbook` and `Workbook.constantMemory` for in-memory and constant-memory
  writing, with a `NativeFinalizer` so a forgotten workbook is freed.
- `Worksheet` writes: `writeString`, `writeNumber`, `writeBool`,
  `writeFormula`, `writeDateTime`, `writeUrl`, `writeBlank`.
- Layout: `setColumn`, `setColumnWidth`, `setRow`, `mergeRange`, `freezePanes`.
- `Format` with `bold`, `italic`, `underline`, `fontName`, `fontSize`,
  `fontColor`, `backgroundColor`, `numberFormat`, `align`, `verticalAlign`,
  `textWrap`, `border`, and `borderColor`.
- libxlsxwriter error codes surfaced as `XlsxWriterException` with the
  human-readable message.
