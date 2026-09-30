# xlsxwriter examples

Three programs, for the things people write spreadsheets for.

| file | what it is for |
| --- | --- |
| [`xlsxwriter_example.dart`](xlsxwriter_example.dart) | An export too big to hold in memory. Streams rows to disk and measures what that costs. |
| [`formatted_report.dart`](formatted_report.dart) | A presentation report: merged title, styled headers, currency and date formats, a live formula, frozen panes, an autofilter, a defined name, and a chart. |
| [`chart_report.dart`](chart_report.dart) | A small sales sheet with a column chart and a pie: titles, axis names, series names, a moved legend, and pie percentages. |

All three write into a temporary directory and leave nothing behind in the
directory you ran from.

Run them with `dart run`. Compiling one from this repository with
`dart compile exe` exits 0 and then produces a binary that dies on its first
call with exit 255, because `dart compile` does not run build hooks and the
native library never makes it into the snapshot (elided in the middle):

```
Unhandled exception:
Invalid argument(s): Couldn't resolve native function
'xlsxw_workbook_new_constant_memory' in 'package:xlsxwriter/src/bindings.dart'
: ... No available native assets.
```

`dart build cli` is the command that carries the library along; see "Platforms
and requirements" in the main README.

## Streaming a large export

```
dart run example/xlsxwriter_example.dart
```

The interesting part is one constructor. `Workbook.constantMemory` keeps a
single row in memory: the row you are writing now. Moving to a higher row
number serializes the previous row straight to XML in a temporary file and
frees its cells. Peak memory then tracks the width of a row instead of the
height of the sheet. Everything after that line is the export you would have
written anyway:

```dart
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final workbook = Workbook.constantMemory('orders.xlsx');
  try {
    final sheet = workbook.addWorksheet('Orders');
    sheet.writeRow(0, const ['Order', 'Customer', 'Units']);

    // Top to bottom, one row at a time. Nothing accumulates.
    for (var row = 1; row <= 1000000; row++) {
      sheet.writeRow(row, ['SO-$row', 'Customer ${row % 5000}', row % 97 + 1]);
    }
  } finally {
    workbook.close(); // close() is the call that writes the file
  }
}
```

### What it prints

Peak memory is read from `ProcessInfo.maxRss`, which is a whole-process peak
rather than a workbook measurement. The example samples it once before the
first write and once at the end. The difference is the part the export is
actually responsible for; without that subtraction the writer gets billed for
the Dart VM hosting it. On an Apple Silicon laptop, Dart 3.11:

```
  mode        constant memory (Workbook.constantMemory)
  workload    200,000 rows x 5 columns
  wrote       5.8 MiB in 1.16s

  peak RSS    188.9 MiB   highest this process reached
  before      188.9 MiB   already reached before the first write
  the sheet     0.0 MiB   how much writing it raised the peak
```

The last line is the claim. Streaming 200,000 rows never pushed the process
past where the VM had already been, and `--rows=1000000` does not move it
either. The same export built in memory does:

```
dart run example/xlsxwriter_example.dart --mode=default
```

```
  peak RSS    330.2 MiB   highest this process reached
  before      188.8 MiB   already reached before the first write
  the sheet   141.4 MiB   how much writing it raised the peak
```

Because `maxRss` is a whole-process peak, the two modes have to be separate
runs; in one process whichever peaked higher would hide the other.
[`bench/bench.dart`](../bench/bench.dart) automates both runs and prints them
side by side, with the same baseline column; it is where the two `xlsxwriter`
rows in the main README's benchmark table come from. With `--compare` it also
runs the `excel` packages from `bench/competitors/`, which sit in their own
pubspecs for a dependency reason the main README explains.

Other flags: `--rows=N` to pick your own size, `--keep` to leave the `.xlsx`
behind and print its path so you can open it.

### The one rule it adds

Streaming costs you random access, and the example demonstrates the two ways
you will hit that rather than just describing them. The second message is one
long line; it is wrapped here to fit:

```
  writeString(0, 2, ...)      -> Worksheet row or column index out of range.
  mergeRange(0, 0, 0, 4, ...) -> a merge in constant-memory mode must start at
                                 or after the highest row written so far (1);
                                 earlier rows have been flushed to disk and the
                                 merge would be silently dropped
```

Write top to bottom. Once you advance past a row it is XML on disk and its
cells are freed. Writing back to it throws `XlsxWriterException`, and
libxlsxwriter words that as *"index out of range"*, which is misleading: the
index is fine, the row is gone. A `mergeRange` that reaches back is caught
by this package instead, with a message naming the row, because libxlsxwriter
would otherwise drop the merge and report nothing.

Column order *within* the row you are on does not matter, in either mode. Use
the default `Workbook(...)` when you genuinely need to write out of order.

## A formatted report

```
dart run example/formatted_report.dart
```

Merged and colored title, styled header row, currency and date number formats,
a live `=B3*C3` formula, column widths, frozen panes, an autofilter over the
table, a defined name for the units column, and a column chart. This one uses
the default `Workbook(...)`, which holds the workbook in memory and in
exchange lets you write cells in any order. That is the right trade for a
report of this size.

Charts are worth calling out: the pure-Dart writers cannot produce them at all.

Note the enum names: `HorizontalAlignment` and `CellBorder` (renamed from
`Alignment`/`Border` in 0.9.0 so they don't clash with Flutter's own types when
you write a spreadsheet from a Flutter app).

## A chart report

```
dart run example/chart_report.dart
```

A three-region sales table, a column chart with a title, axis names, named
series and the legend at the bottom, and a pie of the yearly mix with
percentages on the slices. Same in-memory `Workbook(...)` as the formatted
report.
