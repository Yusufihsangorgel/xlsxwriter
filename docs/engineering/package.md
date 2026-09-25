# Package engineering rules: xlsxwriter

Rules-Version: xlsxwriter/0bb6461f13e945b996ac10cb855d4023882c4b27c1928c4b10f8a2312bdb77cd
Core-Version: 1
Core-Digest: 1825fa7ff346dca23e65b1b3bf9b2e3e06959f1414bae9952d596d2f62f09b8f
Survey-Digest: f90f45c8a172068c3ed3b9488ba5a7cb4e58efa93c380d2d9a70b399349ec35e
Evidence-Revision: e9a611b
Verified-Revision: unverified

Read CONTRIBUTING.md and docs/engineering/debt.json before editing.

## Current architecture
HEAD e9a611b (1.4.2). libxlsxwriter, minizip, and zlib 1.3.1 are vendored. A flat C ABI shim sits on top (`xlsxw_*`, `XLSXW_EXPORT`). Rows and columns arrive from FFI as `uint32`. The shim narrows the column to `lxw_col_t` (uint16). The Dart side has one library: `workbook.dart` with its part files `worksheet.dart`, `format.dart`, `chart.dart`. Workbook owns every native handle. Child objects bind to its lifecycle through a private constructor and `_workbook._ensureOpen()`. Shared private helpers: `_check` (lxw_error -> XlsxWriterException), `_validateCell` (32-bit truncation guard), `_checkNoEmbeddedNul`. `enums.dart` carries the native value on public enums through `.value`. Tests read the produced .xlsx back as zip/XML. A correctness bug found by reading code: column validation is 32-bit while the shim narrowing is 16-bit. Columns between 65536 and 2^32-1 wrap silently.

## Layers and responsibilities
- lib/xlsxwriter.dart: Only `export ... show` (lines 28-38).
- lib/src/workbook.dart (+ part worksheet.dart, format.dart, chart.dart): Workbook, Worksheet, Format, Chart; `_check`, `_formatHandle`, `_validateCell`, `_checkNoEmbeddedNul`.
- lib/src/enums.dart: 7 public enums, each `const X(this.value)`.
- lib/src/exception.dart: XlsxWriterException(code), message from `xlsxw_strerror`.
- lib/src/bindings.dart: 49 `@Native`, 3 lxw_error constants, the workbook finalizer pointer; not exported.
- src/xlsxwriter_shim.c/.h, src/third_party/{libxlsxwriter, zlib}: A 416-line C shim; `XLSXW_EXPORT`; type narrowing.
- hook/build.dart: TU lists identical to upstream, conditional Windows sources and defines, c11.
- test/ (xlsx_reader.dart), tool/, bench/ (competitors excluded from analysis): Read-back tests; figure and benchmark generators.

## Public API and dependency direction
Workbook(path), Workbook.constantMemory(path), static Workbook.toBytes(build, {constantMemory}); addWorksheet, addFormat, defineName, addChart, close, isClosed. Worksheet: writeString/Number/Bool/Formula/DateTime/Url/Blank, writeRow(List<Object?>), setColumn, setColumnWidth, setRow, mergeRange, autofilter, freezePanes, addTable, insertChart, insertImage, conditionalCell/Between/ColorScale/DataBar. Format: chainable setters (bold, italic, underline, fontName, fontSize, fontColor, backgroundColor, numberFormat, align, verticalAlign, textWrap, border, borderColor). Chart: addSeries, setTitle, setAxisNames, setLegend, setStyle. Enums: HorizontalAlignment, VerticalAlignment, Underline, CellBorder, ChartType, ChartLegendPosition, ConditionalCriteria; all expose a public `.value`. XlsxWriterException(code, message). The boundary is lib/xlsxwriter.dart:28-38.

xlsxwriter.dart -> {enums, exception, workbook}. workbook (+ parts) -> bindings, enums, exception, package:ffi, dart:io. exception -> bindings, package:ffi. enums -> nothing. bindings -> dart:ffi, package:ffi. No cycle. Worksheet, Format, and Chart are created only through Workbook (private constructor).

## Error, state and platform contracts
- Ownership: a single Finalizable Workbook. Child objects use part + private constructor + `_workbook._ensureOpen()` (workbook.dart:11-13, 33, 218-222).
- FFI text: `_checkNoEmbeddedNul` -> `toNativeUtf8` -> `malloc.free`. Each of the two calls appears 17 times in the library.
- Coordinates: `_validateCell` guards 32-bit wrapping (workbook.dart:233-267).
- Errors: `_check(code)` -> XlsxWriterException (strerror message); the matching `lxwError*` constant for a null handle; ArgumentError.value; StateError('Workbook has been closed.').
- Close is idempotent. The finalizer detaches before the native close (workbook.dart:208-216).
- Constant-memory ordering is tracked with `_maxRowWritten` (worksheet.dart:14-23).
- The enums are split in two: format enums mirror libxlsxwriter values and chart enums use shim identities (enums.dart:3 <-> 138-141).
- Chainable builder: Format setters `return this`.
- Bounded testing: the produced file is read back as zip/XML through test/xlsx_reader.dart (archive and xml dev dependencies).
- Hook: TU lists identical to the upstream build systems, plus conditional Windows sources (hook/build.dart:23-121).
- Global state is only const/final (lxwError* constants, _maxCellIndex, finalizer).
- Documentation layout: AGENTS.md targets users.

## Package rules
### xlsxwriter/XW-01 [MUST]
The public API is exposed only through the `lib/xlsxwriter.dart` show lists; bindings.dart is not exported.
Reason: The bindings are declared 'not exported' in their own header.
Evidence: lib/xlsxwriter.dart:28-38; lib/src/bindings.dart:13-14
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-02 [MUST]
Every native type owned by the Workbook (Worksheet, Format, Chart and newer ones) is added as `part of 'workbook.dart'`, with a private constructor and a `_workbook` reference. Every public method calls `_workbook._ensureOpen()` first.
Reason: Child handles are freed when the workbook closes; a child object of a closed workbook must not be used.
Evidence: lib/src/workbook.dart:11-13, 218-222; lib/src/worksheet.dart:1, 8-12, 33; lib/src/format.dart:1, 18-29; lib/src/chart.dart:1, 23-27, 45
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-03 [MUST]
Every String going to C first passes `_checkNoEmbeddedNul(value, 'ad')`, then `toNativeUtf8()`, and is released with `malloc.free` in the same function.
Reason: libxlsxwriter has no pointer + length string API; U+0000 silently truncates the content on the C side.
Evidence: lib/src/workbook.dart:269-283; lib/src/worksheet.dart:32-51
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-04 [MUST]
Every method taking a cell or range coordinate calls `_validateCell` (or an equivalent column/row validation). A value the native parameter or the shim narrowing cannot carry is rejected with `ArgumentError.value` before it reaches native code.
Reason: Truncation in the FFI and the shim makes the value silently land in a different cell; a valid file with wrong data.
Evidence: lib/src/workbook.dart:233-267; lib/src/worksheet.dart:34, 391-392, 470, 508
Evidence role: both
Existing violation: xlsxwriter-D001, xlsxwriter-D002

### xlsxwriter/XW-05 [MUST]
Native lxw_error returns are converted to XlsxWriterException through `_check(code)`. Paths that return a null handle use the matching code from the `bindings.lxwError*` constants; the message comes from strerror.
Reason: A single native error type with its code and description.
Evidence: lib/src/workbook.dart:101-103, 137-140, 152-154, 225-228; lib/src/exception.dart:12-27; lib/src/bindings.dart:15-30
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-06 [MUST]
Error contract: native error -> XlsxWriterException; parameter -> ArgumentError.value(value, 'name', message); closed workbook -> StateError. Dartdoc names the thrown type correctly.
Reason: Callers distinguish these three classes (example/xlsxwriter_example.dart:191-202).
Evidence: lib/src/workbook.dart:218-222, 244-266; example/xlsxwriter_example.dart:191-202
Evidence role: current-pattern
Existing violation: xlsxwriter-D003

### xlsxwriter/XW-07 [MUST]
close() is idempotent; the finalizer is detached before the native close call.
Reason: workbook_close frees even on error; not allocating first would mean a double free.
Evidence: lib/src/workbook.dart:208-216
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-08 [MUST]
The ordering rule in constant-memory mode is kept: writing to a row already passed raises XlsxWriterException; `_maxRowWritten` rejects a merge that extends backwards.
Reason: Earlier rows are already written to disk; a documented trade-off.
Evidence: lib/src/workbook.dart:40-51; lib/src/worksheet.dart:14-23; test/constant_memory_merge_test.dart
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-09 [MUST]
A new enum either uses stable identities owned by the shim (the ChartType and ChartLegendPosition pattern) or, when it mirrors a libxlsxwriter value, adds a test that pins the values against the vendored header.
Reason: Mirrored values can drift silently on an upstream upgrade.
Evidence: lib/src/enums.dart:3, 37, 62, 87 <-> 138-141, 183-186
Evidence role: current-pattern
Existing violation: xlsxwriter-D006

### xlsxwriter/XW-10 [MUST]
A new write feature comes with a test that reads the produced .xlsx back as zip/XML through test/xlsx_reader.dart; a test that checks only Dart-side state does not count as enough.
Reason: A test without a bound restates the same fact twice; the file format is the real bound.
Evidence: test/xlsx_reader.dart; pubspec.yaml dev_dependencies (archive, xml)
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-11 [MUST]
The hook TU lists stay one-to-one with the upstream build systems. zlib is built vendored on every platform; iowin32.c and the Windows defines stay conditional.
Reason: There is no system zlib on Windows; a missing or extra TU gives a link error.
Evidence: hook/build.dart:8-14, 23-86, 104-121
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-12 [MUST]
The `bench/competitors/**` exclusion in analysis_options.yaml is kept; this directory stays isolated with its own pubspec.
Reason: excel 4.0.6 requires archive ^3; it cannot be a dependency of this package.
Evidence: analysis_options.yaml:3-8
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-13 [SHOULD]
Format setters stay chainable (`return this`).
Reason: A documented usage pattern.
Evidence: lib/src/format.dart:5-13, 25-29
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-14 [MUST]
Package level holds only const/final fields; no mutable global state is added.
Reason: The current code follows this.
Evidence: lib/src/bindings.dart:22-30, 564; lib/src/workbook.dart:111, 242
Evidence role: current-pattern
Existing violation: none

### xlsxwriter/XW-15 [MUST]
A new cell or range API follows this skeleton: `_ensureOpen` -> coordinate validation for every corner -> `_checkNoEmbeddedNul` for text -> `toNativeUtf8` -> `_check(bindings.xlsxw*)` -> finally free. In the shim, an `xlsxw_*` wrapper with `XLSXW_EXPORT`.
Reason: The current extension point.
Evidence: lib/src/worksheet.dart:32-51, 377-447; src/xlsxwriter_shim.h:28-39
Evidence role: current-pattern
Existing violation: none

## Required verification
- Working directory: repository root; command: dart pub get; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:23.
- Working directory: repository root; command: dart format --output=none --set-exit-if-changed lib test bench example hook tool; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:24.
- Working directory: repository root; command: dart analyze --fatal-infos; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:25.
- Working directory: repository root; command: dart test; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:26.
Not verified by the survey:
- The column wrap bug was not executed. The chain was derived by reading code: bindings.dart:76-79 Uint32 -> xlsxwriter_shim.c:53 `(lxw_col_t)col` -> the libxlsxwriter `LXW_COL_MAX` check accepting the wrapped value.
- Whether the toBytes error path fails to delete the temporary directory on Windows because of an open file was not measured.
- Whether bench/competitors enters the published archive (no `.pubignore`) was not measured.
- `dart analyze`/`dart test` were not run; CI status (no network).
- The shim's 416 lines were scanned only through narrowing and export markers.

## Existing debt
The complete register is docs/engineering/debt.json.
- xlsxwriter-D001 | small | lib/src/workbook.dart:242, 259-265 <-> src/xlsxwriter_shim.c:5-6, 53, 60, 67, 74, 90, 97, 104, 110, 124-137, 234-235, 319, 336, 364-415 | correctness: silent data corruption
  Fix: A separate upper bound for the column (0xFFFF; libxlsxwriter keeps reporting the Excel limit with its own error), in all column paths including setColumn. A `writeNumber(0, 0x10003, 1)` throwsArgumentError test and a CHANGELOG entry.
  Closure: Every column path, including setColumn, rejects columns above 0xFFFF before the native call. A writeNumber(0, 0x10003, 1) test expects ArgumentError and CHANGELOG.md records the fix.
- xlsxwriter-D002 | small | lib/src/worksheet.dart:239-253, 261-271 | inconsistent validation
  Fix: Row and column validation helpers + `ArgumentError.value`; a range-order check; a test.
  Closure: setColumn and setRow validate bounds through shared helpers that throw ArgumentError.value and reject firstCol greater than lastCol. A test covers the out-of-range and reversed-range cases.
- xlsxwriter-D003 | small | lib/src/worksheet.dart:375, 458 <-> lib/src/workbook.dart:244-266 | documentation drift
  Fix: Fix the dartdoc to ArgumentError.
  Closure: The addTable and insertChart dartdoc names ArgumentError for coordinate errors, matching what _validateCell throws.
- xlsxwriter-D004 | small | lib/src/workbook.dart:73-89 | resource cleanup
  Fix: Free without writing on the error path (detach + native free) and a 'build throws' test.
  Closure: toBytes detaches the finalizer and frees the workbook without writing when build throws. A test forces build to throw and covers the error path.
- xlsxwriter-D005 | small | lib/src/chart.dart, format.dart, workbook.dart, worksheet.dart (17 toNativeUtf8 call sites) | duplicated logic
  Fix: A `_withCString(String value, String name, void Function(Pointer<Utf8>))` helper that also contains the NUL check.
  Closure: All native string sites route through a single _withCString helper that performs the NUL check and the try/finally malloc.free.
- xlsxwriter-D006 | small | lib/src/enums.dart:3, 37, 62, 87 | upstream coupling / leaking native value
  Fix: A header-pinning test for the mirrored values. `.value` stays to avoid a breaking change; new enums use a shim identity.
  Closure: A test pins every mirrored Format enum value against the vendored libxlsxwriter header. The .value getter remains and new enums use shim identities.
- xlsxwriter-D007 | small | analysis_options.yaml:1 | analysis strictness
  Fix: Turn on the image_ffi settings.
  Closure: analysis_options.yaml enables the image_ffi strict settings and dart analyze reports no new diagnostics.
