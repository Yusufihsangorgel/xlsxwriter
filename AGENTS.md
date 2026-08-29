# xlsxwriter

Writes Excel `.xlsx` files from Dart via FFI to libxlsxwriter. Constant-memory
mode (`Workbook.constantMemory`) streams each row to disk so peak memory does
not grow with sheet height.

It is write-only: it does not read or edit an existing file. Linux, macOS, and
Windows only (standalone Dart). Flutter, web, Android, and iOS are unsupported:
`pubspec.yaml` `platforms:` lists those three, and `hook/build.dart` has no
Android or iOS handling.

## Usage

From `example/xlsxwriter_example.dart`:

```dart
import 'package:xlsxwriter/xlsxwriter.dart';

void main() {
  final workbook = Workbook.constantMemory('orders.xlsx');
  try {
    final sheet = workbook.addWorksheet('Orders');
    sheet.writeRow(0, const ['Order', 'Customer', 'Units']);
    for (var row = 1; row <= 200000; row++) {
      sheet.writeRow(row, ['SO-$row', 'Customer ${row % 5000}', row % 97 + 1]);
    }
  } finally {
    workbook.close();
  }
}
```

`Workbook(path)` holds the workbook in memory and allows out-of-order writes.
`Workbook.toBytes((workbook) { ... })` closes for you and returns a `Uint8List`;
pass `constantMemory: true` for the same row-order rule.

## Contracts

**Close.** Only `Workbook.close` writes the file. `Worksheet`, `Format`, and
`Chart` have no close method; they are owned by the workbook. `close()` is
idempotent. Using any of them afterwards throws `StateError`:
`Workbook has been closed.` A workbook garbage-collected without `close()` is
freed by a `NativeFinalizer`; the file is never written. The parent directory
of the path must already exist.

**Constant memory (`Workbook.constantMemory`).** A row is flushed when a later
row is written. After that, these are illegal:

- Cell writes (`writeString`, `writeNumber`, `writeBool`, `writeFormula`,
  `writeDateTime`, `writeUrl`, `writeBlank`, `writeRow`) and `setRow` on an
  earlier row: `XlsxWriterException(24): Worksheet row or column index out of
  range.` The index is in range; the row is gone.
- `Worksheet.mergeRange` whose `firstRow` is below the highest row written:
  `ArgumentError` on `firstRow`. libxlsxwriter would drop the merge silently.

Column order within the current row does not matter. A merge that starts at or
after the current row is legal. Use `Workbook(path)` for random access.

**Indices.** 0-based: `(0, 0)` is `A1`. Excel limits: rows `0..1048575`, columns
`0..16383` (`LXW_ROW_MAX` / `LXW_COL_MAX`). `_validateCell` rejects negatives
and values `> _maxCellIndex` (`0xFFFFFFFF`) so the `Uint32` FFI slot cannot wrap
and write the wrong cell.

**`writeRow`.** `Worksheet.writeRow` dispatches by runtime type: `String`,
`int`/`double`, `bool`, `DateTime`, `null`. A `DateTime` requires `dateFormat:`.
Any other type is `ArgumentError`.

## Mistakes

- Skip `close()`. No exception; the file is never created. Call `close()` in a
  `try`/`finally`.
- Use after `close()`. `Bad state: Workbook has been closed.`
- Write backwards in constant-memory mode.
  `XlsxWriterException(24): Worksheet row or column index out of range.`
  Write top to bottom, or use `Workbook(path)`.
- `mergeRange` into a flushed row.
  `Invalid argument (firstRow): a merge in constant-memory mode must start at or after the highest row written so far (1); earlier rows have been flushed to disk and the merge would be silently dropped: 0`
  Merge at or ahead of the current row.
- `writeRow` with a `DateTime` and no `dateFormat`.
  `Invalid argument (values[0]): a DateTime needs a dateFormat to render as a date: Instance of 'DateTime'`
  Pass `dateFormat: workbook.addFormat()..numberFormat('yyyy-mm-dd')`.
- Unsupported `writeRow` type.
  `Invalid argument (values[1]): unsupported cell type Object in column 1: Instance of 'Object'`
- Embedded U+0000 in a string.
  `Invalid argument (value): must not contain a U+0000 code unit: "ab\u0000cd"`
- `writeNumber` of NaN or Infinity.
  `Invalid argument (value): must be finite; Excel has no NaN or Infinity: NaN`
- String longer than 32,767 characters.
  `XlsxWriterException(22): String exceeds Excel's limit of 32,767 characters.`
- Invalid or duplicate sheet name.
  `XlsxWriterException(13): Function parameter validation error.`
  Names: 31 characters or fewer, unique, none of `[ ] : * ? / \`.
- Parent directory of the path does not exist.
  `XlsxWriterException(2): Error creating output xlsx file. Usually a permissions error.`
  Create the directory first; `close()` is what creates the file.
- `dart compile exe` does not run build hooks. From this repo the binary then
  dies with `Couldn't resolve native function 'xlsxw_workbook_new_constant_memory'`
  / `No available native assets.` A dependent package fails at compile with
  `'dart compile' does not support build hooks, use 'dart build' instead.`
  Use `dart build cli` and ship the bundle (`bin/` plus the dylib in `lib/`).

## Layout

- `lib/xlsxwriter.dart` — public API (`Workbook`, `Worksheet`, `Format`,
  `Chart`, `XlsxWriterException`, enums).
- `lib/src/` — implementation; FFI in `bindings.dart`.
- `example/` — `xlsxwriter_example.dart` (stream), `formatted_report.dart`.
- `test/` — `dart test`; written files are checked with `xlsx_reader.dart`.
- `hook/build.dart` — compiles `src/xlsxwriter_shim.c` with vendored
  libxlsxwriter and zlib into one dylib, asset `src/bindings.dart`.
- `src/third_party/` — C sources.

Dart `^3.10.0`. Needs a C toolchain (Clang or GCC; MSVC on Windows). The first
`dart test` or `dart run` builds the native library; later builds are cached.

```
dart test
dart analyze --fatal-infos
```
