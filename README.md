# xlsxwriter

![xlsxwriter banner](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/banner.png)

A native, fast, low-memory Excel `.xlsx` writer for Dart. It is an FFI binding
to [libxlsxwriter](https://github.com/jmcnamara/libxlsxwriter) by John McNamara,
compiled from vendored C source at build time. It writes spreadsheets; it does
not read them. The one feature that sets it apart from the pure-Dart writers is
a constant-memory mode that streams rows to disk, so a sheet of a million rows
never has to fit in RAM.

If you need to read or edit existing files, use
[`excel`](https://pub.dev/packages/excel) or
[`spreadsheet_decoder`](https://pub.dev/packages/spreadsheet_decoder). This
package is for the export and report-generation path: turning rows of data into
an `.xlsx` quickly and with flat memory, with formats, tables, charts, images,
and conditional formatting along the way.

## How constant-memory writing works

An `.xlsx` file is a ZIP archive of XML documents. Rename one to `.zip`, unpack
it, and you find a small tree of parts: `[Content_Types].xml`, `_rels/.rels`,
`xl/workbook.xml`, `xl/styles.xml`, and one `xl/worksheets/sheetN.xml` per
sheet. For a large export almost all of the bytes are in one part: the worksheet
XML, a flat stream of `<row>` elements holding `<c>` cell elements, in strict
document order, top row first and left column first within each row.

That ordering is what makes streaming possible. The worksheet part is written in
document order and is never read back while you build it, so the writer never
needs to revisit a row it has already emitted. A format that is append-only in
document order is one you can stream.

There are two ways to produce that XML:

- **Default mode** builds the whole workbook in memory first. libxlsxwriter
  keeps every row in a red-black tree, and every cell in another, all resident
  until `close()`. Peak memory grows with the total number of cells. A million
  rows by ten columns is ten million cell objects alive at once, about 1.4 GiB
  in the benchmark below.
- **Constant-memory mode** (`Workbook.constantMemory`) keeps exactly one row in
  memory: a single reused row plus a per-column array for the cells of the row
  you are writing now. When you move to a higher row number, that row is
  serialized straight to XML in a temporary file on disk and its cells are
  freed. At `close()`, the temp file (already the finished sheet XML) is copied
  into the ZIP and deflated with zlib. Peak memory tracks your widest row, not
  the sheet, so the curve is flat: about 189 MiB from ten thousand rows to a
  million.

![Constant-memory mode keeps one row in RAM while earlier rows are already XML in an on-disk temp file, copied into the .xlsx zip at close](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/mechanism.png)

The cost of streaming is random access. Once you advance past a row it is on
disk and gone: writing back to an earlier row throws an `XlsxWriterException`,
and features that revisit cells, such as merged ranges, do not work in
constant-memory mode. Write top to bottom. Column order within the current row
does not matter, since those cells stay in the per-column array until the row
flushes. Default mode gives up the flat curve in exchange for writing and
overwriting cells in any order.

## Quick start

```dart
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final workbook = Workbook('report.xlsx');
  final sheet = workbook.addWorksheet('Summary');

  final header = workbook.addFormat()
    ..bold()
    ..backgroundColor(0x4472C4)
    ..fontColor(0xFFFFFF);

  // writeRow picks the cell type per value: String -> text, int/double ->
  // number, bool -> boolean, DateTime -> date, null -> blank.
  sheet.writeRow(0, ['Item', 'Amount'], format: header);
  sheet.writeRow(1, ['Widgets', 1250]);
  sheet.writeRow(2, ['Gadgets', 340]);

  workbook.close(); // close() writes the file; always call it
}
```

Rows and columns are 0-based integers, matching libxlsxwriter: `(0, 0)` is cell
`A1`, `(1, 2)` is `C2`. A `try`/`finally` around `close()` is a good fit; a
workbook that is garbage-collected without `close()` is freed by a
`NativeFinalizer` (so no leak) but its file is never written.

## Streaming a large export

For an export that might not fit in RAM, open the workbook in constant-memory
mode. Rows flush to disk as you go:

```dart
final workbook = Workbook.constantMemory('big.xlsx');
final sheet = workbook.addWorksheet('Export');

sheet.writeRow(0, ['id', 'label', 'amount']);
for (var row = 1; row <= 1000000; row++) {
  sheet.writeRow(row, ['SKU-$row', 'Item $row', row * 1.5]);
}
workbook.close();
```

Write rows top to bottom. Writing back to a row you have already passed throws
`XlsxWriterException`.

## Benchmark

Write-only, N rows by 10 columns (one text column, nine numeric). Each engine is
measured in its own process so the peak-memory reading is isolated. Apple
Silicon, Dart 3.11; treat the figures as indicative, not a spec.

![Peak memory vs row count: constant-memory mode holds about 189 MiB flat from 10k to 1M rows, while the in-memory default climbs to 1.4 GiB and excel sits above 1.9 GiB at 100k](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/benchmark.png)

At 100,000 rows:

| engine | time | peak memory |
| --- | ---: | ---: |
| `xlsxwriter` (constant memory) | 0.92 s | 189 MiB |
| `xlsxwriter` (default) | 0.94 s | 314 MiB |
| `excel` 4.0.6 (pure Dart) | 4.05 s | 1917 MiB |

Against `excel`, the pure-Dart writer most people reach for, constant-memory
mode uses about ten times less memory and runs about four times faster at
100,000 rows. Memory is the real argument, and it widens as rows grow: the
constant-memory line stays flat while an in-memory writer keeps climbing. The
`excel` figure was measured in a separate project, because `excel` and this
package's dev dependency `archive` need incompatible major versions of
`archive`, which is also why `bench/bench.dart` measures only the two
`xlsxwriter` modes.

Reproduce this package's two modes with `dart run bench/bench.dart 100000 10`
(see `bench/bench.dart` for the workload).

## What you can write

A short tour; see the API docs for the full set.

**Values, a row at a time.** `writeRow` takes a `List<Object?>` and dispatches
each value by runtime type. A `DateTime` needs a `dateFormat` to render as a
date rather than a serial number:

```dart
final date = workbook.addFormat()..numberFormat('yyyy-mm-dd');
sheet.writeRow(0, ['Item', 'Qty', 'Price', 'Added']);
sheet.writeRow(1, ['Widget', 12, 4.99, DateTime.utc(2026, 7, 20)],
    dateFormat: date);
```

Or write cells one at a time: `writeString`, `writeNumber`, `writeBool`,
`writeFormula`, `writeDateTime`, `writeUrl`, `writeBlank`.

**Formats.** `workbook.addFormat()` returns a `Format` whose setters chain and
can be reused across any number of cells:

```dart
final money = workbook.addFormat()..numberFormat(r'$#,##0.00');
sheet.writeNumber(1, 3, 1999.5, money);
```

The attributes are `bold`, `italic`, `underline`, `fontName`, `fontSize`,
`fontColor`, `backgroundColor`, `numberFormat`, `align`, `verticalAlign`,
`textWrap`, `border`, and `borderColor`. Colors are 24-bit RGB, `0xRRGGBB`.

**Tables.** Wrap a range in an Excel table for banded rows, a per-column filter,
and a name you can use in formulas:

```dart
sheet.addTable(0, 0, 3, 1, name: 'Sales', columns: ['Item', 'Amount']);
```

**Charts.** Write a real Excel chart from data on a sheet. The pure-Dart writers
cannot produce charts, so this is a reason to reach for a native writer:

```dart
final chart = workbook.addChart(ChartType.column)
  ..setTitle('Units sold')
  ..setAxisNames(category: 'Item', value: 'Units')
  ..addSeries(
    categories: r'=Summary!$A$2:$A$4',
    values: r'=Summary!$B$2:$B$4',
    name: 'Units',
  );
sheet.insertChart(0, 3, chart);
```

`ChartType` covers `column`, `bar`, `line`, `area`, `pie`, `doughnut`,
`scatter`, and `radar`.

**Images.** `insertImage` places a PNG, JPEG, GIF, or BMP at a cell straight
from bytes in memory (a logo, or a chart you rendered), so no temporary file is
needed:

```dart
import 'dart:io';
// ...
sheet.insertImage(0, 0, File('logo.png').readAsBytesSync());
```

**Conditional formatting.** Highlight by value, or paint a range as a heatmap or
data bars:

```dart
final red = workbook.addFormat()..backgroundColor(0xFFC7CE);
sheet.conditionalCell(1, 1, 99, 1,
    criteria: ConditionalCriteria.greaterThan, value: 1000, format: red);

sheet.conditionalColorScale(1, 2, 99, 2,
    minColor: 0x63BE7B, maxColor: 0xF8696B);

sheet.conditionalDataBar(1, 3, 99, 3, barColor: 0x638EC6);
```

**Bytes for a server response.** To serve a generated spreadsheet from a request
handler with no scratch file to name and clean up, use `Workbook.toBytes`:

```dart
final bytes = Workbook.toBytes((workbook) {
  final sheet = workbook.addWorksheet('Summary');
  sheet.writeRow(0, ['Item', 'Amount']);
  sheet.writeRow(1, ['Widgets', 1250]);
});
// return Response.ok(bytes, headers: {
//   'content-type':
//       'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
// });
```

Pass `constantMemory: true` to build a large sheet with flat memory, with the
same top-to-bottom ordering rule.

## What it does not do

- **No reading.** It writes files only. To read or edit an existing `.xlsx`, use
  `excel` or `spreadsheet_decoder`.
- **Constant-memory mode is write-forward only.** Rows must be written top to
  bottom. Writing back to an earlier row throws `XlsxWriterException`, and merged
  ranges do not work in this mode (they need to revisit cells). Use the default
  `Workbook(...)` when you need to write out of order or use merges.
- **No NUL bytes in strings.** libxlsxwriter has no pointer+length string API, so
  every string crosses the boundary NUL-terminated. A string containing a U+0000
  code unit throws `ArgumentError` rather than silently truncating.
- **Excel's own limits apply.** Strings over 32,767 characters and URLs over
  2,079 characters throw `XlsxWriterException`.

## Platforms and requirements

- Dart 3.10 or newer, standalone (CLI and server). The native library is built
  by a Dart build hook the first time you run or test the package.
- Linux, macOS, and Windows. `pubspec.yaml` declares exactly these three; the
  build hook has no Android or iOS handling and has not been verified on them.
- A C toolchain on the build machine: Clang or GCC on macOS and Linux, MSVC on
  Windows. No system libraries are needed. libxlsxwriter and zlib are vendored
  and compiled from source, so the package is self-contained.
- Flutter is not supported yet. Build hooks target the Dart standalone runtime
  today; Flutter support depends on native assets stabilizing for Flutter.

CI builds and tests on Ubuntu, macOS, and Windows on every push
(`.github/workflows/ci.yaml`): `dart format`, `dart analyze --fatal-infos`, and
`dart test`, which writes files and reads them back with an independent XML
reader to check the output.

## Install

```
dart pub add xlsxwriter
```

The first build compiles the vendored C, which takes a few seconds; later builds
are cached.

## Credits and license

The engine that does the real work is
[libxlsxwriter](https://github.com/jmcnamara/libxlsxwriter) by **John McNamara**,
under the BSD 2-Clause license. Please credit that project for the `.xlsx`
writing itself.

The Dart binding is under the MIT license (see `LICENSE`). Vendored C keeps its
own licenses: libxlsxwriter (BSD 2-Clause), zlib (zlib license), and the small
libraries libxlsxwriter bundles (minizip, md5, dtoa, tmpfileplus). See
`THIRD_PARTY_NOTICES.md` and `src/third_party/README.md`.
