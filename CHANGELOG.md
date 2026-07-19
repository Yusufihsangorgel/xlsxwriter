## 0.2.0

- Add `Worksheet.addTable`, which wraps a cell range in an Excel table with
  banded rows, per-column autofilter, and a name usable in formulas. Pass the
  column names through `columns`; they are written into the header row. The
  `autofilter`, `bandedRows`, `bandedColumns` and `totalRow` options toggle the
  matching table features.

# Changelog

## 0.1.1

- Move the vendored third-party attributions out of `LICENSE` into
  `THIRD_PARTY_NOTICES.md`, so `LICENSE` is the plain MIT text that automated
  license detection recognises. The attributions themselves are unchanged and
  still ship with the package.

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
