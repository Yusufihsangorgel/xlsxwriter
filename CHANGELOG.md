## 1.4.1

- `code_assets` moved to `^2.0.0`. The 1.x constraint costs a pub.dev
  scorecard point once the grace period on the 2.0.0 release expires. The
  native writer builds unchanged.

## 1.4.0

- `excel_community` 2.3.0, the maintained fork of `excel`, is now in the
  comparison in the README, measured on the same workload at four sizes. It
  writes ten thousand rows faster than this package's default mode (0.26 s
  against 0.31 s); what separates them is memory, and the gap widens with the
  sheet. `bench/compare_writers.sh` and `bench/results/` hold the script and
  the raw runs the table was computed from. Library code is unchanged.

## 1.3.0

- Autofilter and defined names, the two remaining pieces of a report after
  the chart. `Worksheet.autofilter` puts a filter dropdown on each column of
  a range without wrapping it as a table; `Workbook.defineName` names a cell,
  a range, or a constant so a formula can use it. Frozen panes have been
  there since 0.1.0; the three together are what a person building a report
  reaches for once the chart is in. Verified by writing each and reading the
  XML back out of the xlsx zip: `autoFilter` ref, `pane` with
  `state="frozen"`, `definedName`.

## 1.2.0

- Charts: the rest of the report set. Stacked column, bar and line types;
  `Chart.setLegend` to move or hide the legend; `Chart.setStyle` for Excel's
  1-48 chart styles; data labels (and pie percentages) on `addSeries`;
  `insertChart` now takes the same `xOffset`/`yOffset` nudge as `insertImage`.
  0.4.0 could draw a titled chart; a report still needed stacked series, a
  legend that was not stuck on the right, and labels on a pie. Verified by
  writing each and reading the chart XML back out of the xlsx zip: `barChart`
  with `grouping` stacked, `legendPos`, `c:style`, `dLbls`/`showPercent`.
  `example/chart_report.dart` is a small sales sheet with a column chart and a
  pie.

## 1.1.2

- The section on why to reach for this rather than the alternative now sits
  directly under the recording, instead of below a long explanation. Someone
  deciding whether to install it reads the choice before the mechanics, and
  the section was landing past the fold where it answered nobody.

## 1.1.1

- The README opens with a recording of the package running, rendered from a
  real execution rather than drawn: the command is run, its exit code checked,
  and the frames built from the bytes it printed. `tools/term-trailer.sh` in
  the portfolio repository makes it, so it can be regenerated when the numbers
  move.

## 1.1.0

- The README now answers, in its first screen, why to reach for this rather
  than the zero-dependency route or the package that already owns the
  category. Both answers carry the file and line, or the issue number, that
  a reader can check. A "reach for it when" list and a sentence on when to
  skip it follow, because a page that only argues for itself is not useful
  for deciding.

## 1.0.3

- The "How it works" section shows where the bytes go. `tool/anatomy_figure.dart`
  writes the same export at 1,000 and 100,000 rows and reads the ZIP central
  directory of both: eight parts come out byte-identical, and the ninth,
  `xl/worksheets/sheet1.xml`, grows 108.7x and holds 99.93% of the uncompressed
  bytes at 100k. The generator refuses to write the figure if that part stops
  being the one that grows. Docs and tooling only.

## 1.0.2

- Stop billing the writer for the VM hosting it. `ProcessInfo.maxRss` is a
  whole-process peak, and a Dart VM with this package loaded sits near 188 MiB
  before the first cell is written, which is where the README's old "constant
  memory holds about 189 MiB flat" figure came from. The benchmark now samples
  that counter once before the first write and reports the difference in its
  own column. Measured that way at 100,000 rows, the constant-memory export
  raises the process peak by 0.2 MiB, default mode by 124.3 MiB, and `excel`
  4.0.6, in its separate harness, by 1664.5 MiB. The chart plots the
  subtracted figures. Docs, bench and chart only: nothing in `lib/` changed.
- `example/xlsxwriter_example.dart` is now the streaming export as a runnable
  measurement: it writes 200,000 rows, samples `maxRss` before and after,
  reports what the export added, and triggers the two write-backwards errors
  on purpose so their exact messages are on screen rather than paraphrased.
  `--mode=default`, `--rows=N` and `--keep` vary the run. The old API tour,
  merged title through chart, moved to `example/formatted_report.dart`.
- Both examples write into a temp directory instead of the directory you
  happened to run them from.
- The README now says how to ship a compiled binary: `dart compile exe` does
  not run build hooks and refuses with an error pointing at `dart build`, and
  `dart build cli` (still preview in Dart 3.11) emits a bundle with the native
  library beside the executable. Ship the bundle.

## 1.0.1

- **Reject a row or column past 32 bits instead of writing to the wrong
  cell.** The FFI parameters are `Uint32`, and validation only checked for
  negatives, so an index of `2^32 + 3` was truncated to `3` before
  libxlsxwriter could range-check it: the value landed in the fourth row, the
  file was valid, and nothing reported a problem. An index computed from an
  offset, a running sum, or an id is exactly the kind that gets that large,
  and silent corruption is worse than a slow failure.

  Such an index now throws an [ArgumentError] naming the row it would have
  wrapped to. Indices that exceed Excel's own limits but still fit in 32 bits
  are unchanged: they keep failing with [XlsxWriterException] from the native
  range check, as before.

## 1.0.0

The API is stable. One thing had to change before freezing, because it was
silent data loss.

- **A `mergeRange` that reaches back into flushed rows now throws.** In
  constant-memory mode libxlsxwriter drops such a merge and reports nothing, so
  the sheet came out quietly missing it — 0.8.1 could only document that. The
  worksheet now tracks the highest row written and refuses the merge with an
  `ArgumentError` naming that row, before the native call. This covers the
  straddling case (a range starting before the current row and ending after it),
  which is the one that vanished; a wholly backward range already failed, but as
  a native `XlsxWriterException`, and now fails the same way as every other
  programmer error in this package. Merges at or ahead of the current row are
  unaffected, including one starting on the current row, which is not yet
  flushed.

  Breaking only in the exception type for a merge that was already failing.

Also verified by execution and pinned as tests: using a worksheet or workbook
after `close()` throws instead of touching freed memory, closing twice is safe,
600 workbooks in four batches leave RSS flat, and negative coordinates, NaN,
infinities and embedded NULs are all rejected before reaching native code.

`native_toolchain_c` is pre-1.0 but is a build-time dependency and does not
reach the public API frozen here.

## 0.9.1

- Add `example/README.md` for pub.dev's Example tab (it was empty). It describes
  what `xlsxwriter_example.dart` writes into `example_report.xlsx` — a merged
  title, formatted columns, a live `SUM` formula, a date column, frozen panes,
  and a chart — and notes the 0.9.0 enum renames. Docs only.

## 0.9.0

- **Renamed two enums that shadowed Flutter's own types.** `Alignment` is now
  `HorizontalAlignment` (symmetric with the existing `VerticalAlignment`) and
  `Border` is now `CellBorder`. Both old names collide with
  `package:flutter/material.dart`, and the collision broke the *caller's*
  Flutter code, not ours: importing this package plainly next to material made
  `Alignment.center` and `Border.all()` ambiguous, so a Flutter app exporting a
  spreadsheet had to hide our names or prefix the import. Verified in a real
  Flutter project before and after — `ambiguous_import` on both names before,
  a clean analysis with every exported name in use after. `BorderStyle` was not
  chosen as the replacement because Flutter has one of those too.

  To migrate, rename at the call site: `Alignment.center` becomes
  `HorizontalAlignment.center`, `Border.thin` becomes `CellBorder.thin`. The
  values and their meanings are unchanged.

## 0.8.1

- Reject non-finite numbers. `writeNumber` (and `writeRow`) let `double.nan`,
  `double.infinity` and `-double.infinity` through to libxlsxwriter, which
  wrote `<v>NAN</v>` / `<v>INF</v>` into the cell — tokens that are not valid
  in an xlsx numeric value, so Excel refused to open the file. They now throw
  an `ArgumentError` at the call, before a corrupt file can be produced.
- Correct the constant-memory merge description. 0.8.0 said a `mergeRange` that
  reaches back into flushed rows throws; a range that straddles the current row
  (first row already flushed, last row ahead) does not throw — libxlsxwriter
  silently does not write it. The README now says a merge has to sit entirely
  at or ahead of the current row, which is the accurate rule.

## 0.8.0

Settles the class-modifier and export questions ahead of a 1.0.0 freeze, and
corrects a limitation the README claimed but the code does not have.

- Mark `Workbook`, `Worksheet`, `Format`, `Chart` and `XlsxWriterException` as
  `final`. They are concrete handles over the libxlsxwriter objects, nothing
  in the package, its tests, examples or benchmarks subtypes any of them, and
  the package has added a feature per minor release. Sealing keeps those
  additions non-breaking; adding `final` after 1.0.0 would take a major
  version, while removing it later would not.
- Name the enum exports explicitly rather than re-exporting `src/enums.dart`
  whole, so a future symbol in that file cannot join the API silently. The
  exported set is unchanged.
- Correct the merged-range limitation. The README said merged ranges "do not
  work in constant-memory mode". They do: `mergeRange` in that mode writes a
  correct `mergeCell` as long as the range is at or ahead of the current row,
  and throws only when it reaches back into rows already flushed to disk —
  which is the same write-forward rule that already governs everything else in
  that mode, not a separate limitation. Both places in the README now say
  that, and two tests pin the behaviour in each direction.

## 0.7.2

- Rework the README around how constant-memory mode works: what an `.xlsx`
  actually is, why document-order XML lets you stream one, and what streaming
  costs. Adds a measured memory-vs-rows chart (constant-memory holds about
  189 MiB flat from 10k to 1M rows while the default mode reaches 1.4 GiB) and
  a diagram of the one-row-in-RAM path.
- Fix the `Workbook.constantMemory` doc comment, which said an out-of-order
  write is silently dropped. A backward-row write throws `XlsxWriterException`;
  it is not silent. Column order within the current row does not matter.

## 0.7.1

- Fix a truncation bug: every string-taking API (`writeString`, `writeFormula`,
  `writeUrl`, `mergeRange`, worksheet and table names, format font name and
  number format, chart title/series/axis names) passed the Dart string to
  libxlsxwriter as a NUL-terminated C string. A value containing an embedded
  U+0000 code unit, which is legal Dart content, was silently cut at that
  byte with no error, since libxlsxwriter's own API has no pointer+length
  variant to switch to. These now throw `ArgumentError` on an embedded NUL
  instead of truncating.
- Declare `platforms: {linux, macos, windows}` in `pubspec.yaml`. The build
  hook has no Android/iOS handling and has never built or run on them; pub.dev
  had inferred support for all five platforms from static analysis alone with
  no declaration to override it.

## 0.7.0

- Conditional formatting: the report and dashboard set. `conditionalCell` and
  `conditionalCellBetween` highlight cells in a range by comparison (the
  `ConditionalCriteria` values, or a min/max between) with a `Format`;
  `conditionalColorScale` paints a 2- or 3-colour heatmap; `conditionalDataBar`
  draws in-cell bars proportional to each value. Backed by libxlsxwriter's
  `worksheet_conditional_format_range` through focused shim entry points, one
  per mode, so the fat `lxw_conditional_format` struct does not cross the flat
  ABI. Verified by writing each rule and reading the `conditionalFormatting`
  block back out of the sheet XML: `cellIs`/`greaterThan`, `between`,
  `colorScale` (2- and 3-colour), and `dataBar`.

## 0.6.0

- `Worksheet.insertImage(row, col, bytes, {xScale, yScale, xOffset, yOffset})`
  places a PNG, JPEG, GIF or BMP at a cell from bytes in memory, the shape a
  logo or a rendered chart already has, so no temporary file is needed. Backed
  by libxlsxwriter's `worksheet_insert_image_buffer_opt` through a new shim
  entry point. Empty bytes are an `ArgumentError`; bytes that are not a
  recognised image are an `XlsxWriterException`. Verified by embedding a real
  PNG and confirming the file carries an `xl/media/` part and a drawing.

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
