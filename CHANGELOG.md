## 0.5.0

- `Worksheet.writeRow(row, values, {startCol, format, dateFormat})` writes a
  whole row and dispatches each value by its runtime type: String, int/double,
  bool, DateTime and null map to the right cell type, so a report that is a list
  per row needs one call instead of picking a `write...` per column. A DateTime
  needs a `dateFormat` and an unsupported type is an `ArgumentError` naming the
  column, rather than a silent coercion. Verified by writing a mixed row and
  reading every cell back with an independent reader.
- Show the memory argument on its own. The benchmark compared one size against a
  competitor; the new curve measures peak memory at 10k, 100k and 1M rows and
  shows constant-memory mode holding ~191 MiB flat while the in-memory default
  climbs to 1433 MiB at a million rows. That flat curve is the reason the mode
  exists, and it was asserted in prose before, not shown.

## 0.4.4

- Benchmark against `excel_community`, not just `excel`. The chart and the table
  compared only against `excel`, which has had no release since August 2024, and
  claimed "about five times faster". Against the maintained fork the honest
  figures are 3.2x less memory and 1.7x faster: memory is the real argument and
  throughput is close enough that it should not decide anything. All four
  numbers re-measured in one sitting on one machine.
- Say so in the README, and point readers who need to *read* spreadsheets at
  `excel_community` rather than the unmaintained `excel`.

## 0.4.3

- Widen the native-toolchain constraints so the package can be installed in a
  Flutter app at all. `hooks` 2.1.0 and `native_toolchain_c` 0.19.3 raised their
  `meta` floor to ^1.19.0, and Flutter's SDK pins `meta` to 1.17.0, so
  `flutter pub add` failed at version solving with "flutter from sdk is
  incompatible". Allowing `hooks >=2.0.2` and `native_toolchain_c >=0.19.2`
  lets the solver pick a version that works with the pinned `meta`, while a
  pure-Dart project still resolves to the newest. No API or behaviour change.

## 0.4.2

- Shorten the screenshot description. pub.dev accepts up to 200 characters but
  scores only those under 160, so the previous release published cleanly and
  quietly gave up the documentation points it was meant to earn.

## 0.4.1

- Declare the benchmark chart in `pubspec.yaml` so pub.dev renders it on the
  package page. The chart was already in the repository and the README, but
  pub.dev shows only what the `screenshots:` field points at, so the page a
  reader lands on from search opened with text where the measurement should
  have been.

## 0.4.0

- Add charts. `Workbook.addChart(ChartType)` creates a column, bar, line, area,
  pie, doughnut, scatter, or radar chart; `Chart.addSeries` plots cell ranges,
  with `setTitle` and `setAxisNames` for labels; `Worksheet.insertChart` places
  it on a sheet with optional scaling. The pure-Dart `excel` and
  `spreadsheet_decoder` packages can't write charts, so this is the reason to
  use a native writer when a report needs one. Charts are wired through the C
  shim, which is compiled from vendored source, so there is no new binary to
  install.

## 0.3.0

- Add `Workbook.toBytes`: build a workbook and get its `.xlsx` bytes back with no
  file left on disk, for serving a generated spreadsheet straight from a request
  handler. It stages a temporary file, reads it back, and removes it. Supports
  constant-memory mode via `constantMemory: true`.

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
