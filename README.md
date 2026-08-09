# xlsxwriter

Ask a pure-Dart writer for a hundred thousand rows and it builds every cell as
an object before it serializes anything: `excel` 4.0.6 spends 1.6 GiB on that
export. This package's constant-memory mode streams each row to disk as you
write it and holds one row at a time, whatever the sheet grows to.

```dart
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final workbook = Workbook.constantMemory('big.xlsx');
  final sheet = workbook.addWorksheet('Export');

  sheet.writeRow(0, ['id', 'label', 'amount']);
  for (var row = 1; row <= 1000000; row++) {
    sheet.writeRow(row, ['SKU-$row', 'Item $row', row * 1.5]);
  }
  workbook.close(); // close() writes the file; always call it
}
```

On the machine below, that loop raised the process's peak memory by 0.3 MiB.
`bench/bench.dart` writes the same sheet in both modes at whatever size you
give it, each mode in its own process:

```
dart run bench/bench.dart 1000000 10
```

![What the export itself costs. Constant memory stays flat on zero from 10k to 1M rows; the in-memory default climbs to 1243.6 MiB.](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/benchmark.png)

## Why this instead of what you already have

**Instead of `excel`.** It is the pure-Dart writer most people reach for.
`sheet.dart:16` holds `Map<int, Map<int, Data>> _sheetData`, one `Data` object
per cell for the life of the sheet, each with its own `CellStyle?`,
`CellValue?`, and a back-reference to the `Sheet` (`data_model.dart:5-7`).
`save_file.dart:45` then constructs an `XmlElement` per cell. That is the
source-level reason for the figure above: nothing reaches disk until `save()`
returns the finished bytes.

**Instead of syncfusion_flutter_xlsio.** It is the other real `.xlsx` writer on
pub.dev, and it is not open source. Its LICENSE requires a commercial license
or the Community License, which is limited to organizations under one million
USD in annual revenue with fewer than five developers. Its save path is also
whole-file: `saveAsStream()`, `saveSync()`, and `save()` each return the
completed workbook as bytes (`workbook.dart:6221`, `6238`, `6250` in 34.2.2).

## Reach for it when

- The row count comes from user input, so you cannot bound memory in advance.
- A long-running server or CLI has to write reports while it handles other
  work.
- The sheet needs formats, tables, charts, or conditional formatting rather
  than only values.

Skip it inside a Flutter app, on the web, or on mobile. The pubspec declares
Linux, macOS, and Windows only, because the C library is compiled through
Dart's build hooks and those target the standalone runtime today.

The engine underneath is
[libxlsxwriter](https://github.com/jmcnamara/libxlsxwriter) by John McNamara,
compiled from vendored C at build time. This package writes spreadsheets and
does not read them. To read or edit an existing file, reach for
[`excel`](https://pub.dev/packages/excel) or
[`spreadsheet_decoder`](https://pub.dev/packages/spreadsheet_decoder) instead.
What is covered here is the export and report-generation path: rows of data into
an `.xlsx`, with formats, tables, charts, images, and conditional formatting
along the way.

## What it costs

Write-only, N rows by 10 columns (one text column, nine numeric). Each engine
runs in its own process, because `ProcessInfo.maxRss` is a whole-process peak
and in a shared process the higher peak would hide the other. Apple Silicon,
macOS 26.3, Dart 3.11.0; another machine will give you other numbers.

A Dart VM with this package loaded already sits near 188 MiB before it writes a
single cell. Every run therefore samples that counter once before the first
write and reports the difference too. The last column is the only one that is
about the writer:

| engine | time | peak RSS | baseline | the sheet |
| --- | ---: | ---: | ---: | ---: |
| `xlsxwriter` (constant memory) | 0.79 s | 188.7 MiB | 188.4 MiB | 0.2 MiB |
| `xlsxwriter` (default) | 0.89 s | 312.5 MiB | 188.3 MiB | 124.3 MiB |
| `excel` 4.0.6 (pure Dart) | 4.12 s | 1927.0 MiB | 263.0 MiB | 1664.5 MiB |

At 100,000 rows: medians of five runs for the two `xlsxwriter` modes, three for
`excel`. Each column is its own median, which is why the last one is not the
difference of the two beside it.

Constant-memory mode's cost does not show up at all. Across runs at ten
thousand, a hundred thousand and a million rows the export moved the process
peak by between 0.0 and 0.4 MiB, which is the noise floor of a whole-process
measurement; the per-size medians the chart plots are 0.1, 0.2 and 0.3 MiB.
Default mode's cost is real and linear in cells: 12.5, 124.3 and 1243.6 MiB at
those three sizes. `excel`, the pure-Dart writer most people reach for, spends
1.6 GiB on the same hundred thousand rows and takes about five times as long.

Dividing the raw peaks gives "about ten times less memory". That sentence is
true and it is the wrong number, because it understates: almost all of this
package's 188.7 MiB peak was already there before the first cell, and the ratio
mostly compares two runtimes. Measured on what the export actually added,
`excel` costs 13.4x what default mode does (1664.5 MiB against 124.3). Against
constant memory there is no ratio worth quoting, because the denominator is the
noise floor.

The `excel` row comes from a throwaway package running the same workload with
the same before-and-after sampling. `excel` and this package's dev dependency
`archive` need incompatible major versions of `archive` and cannot share one
pubspec, which is also why `bench/bench.dart` measures only the two
`xlsxwriter` modes. That harness starts 75 MiB higher for the same reason: it
is a different process, with `archive` and an in-memory cell model loaded
before its first write. The chart is redrawn by `dart run tool/benchmark_chart.dart`, which
holds the measured figures as constants; moving the chart means re-running the
benchmark first.

## How it works

An `.xlsx` file is a ZIP archive of XML documents, and for a large export
almost all of the bytes are in one part: the worksheet, a flat stream of `<row>`
elements holding `<c>` cell elements, in strict document order, top row first.
Nothing reads that part back while you build it. A format that is append-only in
document order is one you can stream.

![Nine bars, one per part of the .xlsx, on a log scale. Eight parts have identical lengths in a 1,000-row and a 100,000-row export, and the worksheet part grows 108.7x, from 153 kB to 16.7 MB.](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/anatomy.png)

Writing the same export at a thousand rows and at a hundred thousand bears that
out. Eight of the nine parts come out byte for byte identical: 11,962 bytes of
theme, styles, document properties and relationships that a hundredfold more
data leaves untouched. The worksheet carries all of the growth and ends up
holding 99.93% of the uncompressed bytes. `dart run tool/anatomy_figure.dart`
writes both files, reads their ZIP directories and redraws the chart, and it
refuses to draw anything if a part other than the worksheet has moved.

Constant-memory mode keeps exactly one row: a single reused row, plus a
per-column array for the cells of the row you are on. Moving to a higher row
number serializes the previous row straight to XML in a temporary file and frees
its cells. At `close()` that temp file, already the finished sheet XML, is
copied into the ZIP and deflated with zlib. Default mode instead holds every row
and every cell in red-black trees until `close()`, which is where the 1243.6 MiB
comes from.

The cost of streaming is random access:

```dart
final workbook = Workbook.constantMemory('big.xlsx');
final sheet = workbook.addWorksheet('Export');

sheet.writeRow(0, ['Order', 'Customer']);
sheet.writeRow(1, ['SO-1', 'Customer 1']); // this flushed row 0 to disk
sheet.writeRow(2, ['SO-2', 'Customer 2']); // and this flushed row 1

sheet.writeString(0, 2, 'a late note');    // XlsxWriterException:
                                           // "Worksheet row or column index
                                           //  out of range."
```

![One row in RAM while the rows behind it are already XML in a temp file, and the dashed arrow back is the call that throws.](https://raw.githubusercontent.com/Yusufihsangorgel/xlsxwriter/main/doc/mechanism.png)

That message is worth knowing, because it is misleading: the index is fine, the
row is gone. `mergeRange` works as long as the whole range sits at or ahead of
the current row; one that reaches back throws an `ArgumentError` naming the row
it would have needed. (libxlsxwriter drops such a merge silently, which is why
this package checks first.) Column order within the current row does not matter,
since those cells stay in the per-column array until the row flushes.

`example/xlsxwriter_example.dart` is the streaming loop as a program you can
run: it writes 200,000 rows, reports how much the export raised the process's
peak by sampling `ProcessInfo.maxRss` before and after, and triggers both
ordering errors on purpose. Pass `--mode=default` to build the same sheet in
memory and compare, or `--rows=1000000` to watch the constant-memory figure
stay put.

## Writing a report instead

For a report you assemble out of order, use the plain constructor. It keeps the
workbook in memory and lets you write and overwrite cells in any order:

```dart
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

workbook.close();
```

Rows and columns are 0-based integers, matching libxlsxwriter: `(0, 0)` is cell
`A1`, `(1, 2)` is `C2`. A `try`/`finally` around `close()` is a good fit. A
workbook that is garbage-collected without `close()` is freed by a
`NativeFinalizer`, which means no leak, but its file is never written.

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
cannot produce charts at all:

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
from bytes in memory, with no temporary file to name and clean up. A logo, or a
chart you rendered yourself:

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

Pass `constantMemory: true` to build a large sheet with flat memory, under the
same top-to-bottom ordering rule.

## What it does not do

- It writes files only. To read or edit an existing `.xlsx`, use `excel` or
  `spreadsheet_decoder`.
- Constant-memory mode is write-forward only. Rows have to be written top to
  bottom, and writing a cell back on an earlier row throws
  `XlsxWriterException`. A `mergeRange` has to sit entirely at or ahead of the
  current row; one that reaches back throws `ArgumentError`. Use the default
  `Workbook(...)` when you need to write out of order.
- Strings cannot contain a NUL byte. libxlsxwriter has no pointer+length string
  API, and every string crosses the boundary NUL-terminated. A string holding a
  U+0000 code unit throws `ArgumentError` rather than truncating silently.
- Excel's own limits apply. Strings over 32,767 characters and URLs over 2,079
  characters throw `XlsxWriterException`.

## Platforms and requirements

- Dart 3.10 or newer, standalone (CLI and server). The native library is built
  by a Dart build hook the first time you run or test the package.
- Linux, macOS, and Windows. `pubspec.yaml` declares exactly these three; the
  build hook has no Android or iOS handling and has not been verified on them.
- A C toolchain on the build machine: Clang or GCC on macOS and Linux, MSVC on
  Windows. libxlsxwriter and zlib are vendored and compiled from source, and
  nothing else is needed from the system.
- **Ship with `dart build cli`.** The native library reaches your program as a
  code asset produced by a build hook, and `dart compile exe` does not run build
  hooks: in a package that depends on this one it stops with *"'dart compile'
  does not support build hooks, use 'dart build' instead."* `dart build cli`
  emits a bundle with your executable in `bin/` and the library beside it in
  `lib/` (`libxlsxwriter.dylib` on macOS). Ship the bundle rather than the bare
  binary. The command is still marked preview in Dart 3.11.
- Flutter is not supported yet. Build hooks target the Dart standalone runtime
  today, and Flutter support depends on native assets stabilizing for Flutter.

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
