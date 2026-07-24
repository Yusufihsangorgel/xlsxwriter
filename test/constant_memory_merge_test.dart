import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

/// The README used to say merged ranges do not work in constant-memory mode.
/// They do, under the same write-forward rule as everything else: a range at
/// or ahead of the current row is written, one reaching back into flushed
/// rows throws. These pin that contract.
void main() {
  _nonFiniteTests();
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('xlsx_cm_merge'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a forward merge is written in constant-memory mode', () {
    final path = '${dir.path}/forward.xlsx';
    final workbook = Workbook.constantMemory(path);
    workbook.addWorksheet('s')
      ..mergeRange(0, 0, 0, 3, 'merged header')
      ..writeRow(1, ['a', 'b']);
    workbook.close();

    expect(File(path).lengthSync(), greaterThan(0));
  });

  test('merging back into an already-flushed row throws', () {
    final path = '${dir.path}/backward.xlsx';
    final workbook = Workbook.constantMemory(path);
    final sheet = workbook.addWorksheet('s')..writeRow(5, ['x']);

    expect(() => sheet.mergeRange(0, 0, 0, 3, 'back'), throwsArgumentError);

    try {
      workbook.close();
    } on XlsxWriterException {
      // Closing after the rejected merge is not what this test pins.
    }
  });

  test('a merge straddling the current row throws instead of vanishing', () {
    // The dangerous case: the range starts before the current row but ends
    // after it. libxlsxwriter drops such a merge and reports nothing, so the
    // sheet comes out missing it. The guard has to catch this too, not just a
    // wholly backward range.
    final path = '${dir.path}/straddle.xlsx';
    final workbook = Workbook.constantMemory(path);
    final sheet = workbook.addWorksheet('s')..writeRow(5, ['x']);

    expect(() => sheet.mergeRange(3, 0, 6, 3, 'straddle'), throwsArgumentError);

    try {
      workbook.close();
    } on XlsxWriterException {
      // Not what this test pins.
    }
  });

  test('a merge at or ahead of the current row still works', () {
    final path = '${dir.path}/forward.xlsx';
    final workbook = Workbook.constantMemory(path);
    final sheet = workbook.addWorksheet('s')..writeRow(5, ['x']);

    // Row 5 has not been flushed yet (nothing later has been written), so a
    // merge starting there, or beyond it, is legitimate.
    expect(() => sheet.mergeRange(5, 1, 5, 3, 'same row'), returnsNormally);
    expect(() => sheet.mergeRange(7, 0, 8, 3, 'ahead'), returnsNormally);

    workbook.close();
    expect(File(path).existsSync(), isTrue);
  });
}

// Excel has no NaN or Infinity; libxlsxwriter would emit <v>NAN</v>, which
// makes the file invalid. writeNumber must reject non-finite values.
void _nonFiniteTests() {
  group('non-finite numbers', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('xlsx_nonfinite'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writeNumber rejects NaN and infinities', () {
      final workbook = Workbook('${dir.path}/nf.xlsx');
      final sheet = workbook.addWorksheet('s');
      for (final v in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => sheet.writeNumber(0, 0, v),
          throwsA(isA<ArgumentError>()),
          reason: '$v must be rejected',
        );
      }
      sheet.writeNumber(0, 0, 3.14);
      workbook.close();
    });

    test('writeRow rejects a non-finite number in a row', () {
      final workbook = Workbook('${dir.path}/nfrow.xlsx');
      final sheet = workbook.addWorksheet('s');
      expect(
        () => sheet.writeRow(0, ['ok', double.infinity]),
        throwsA(isA<ArgumentError>()),
      );
      try {
        workbook.close();
      } on XlsxWriterException {
        // closing after the rejected write is not what this pins
      }
    });
  });
}
