import 'dart:io';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';
import 'package:xml/xml.dart';

import 'xlsx_reader.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xlsxwriter_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String pathFor(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  group('container', () {
    test('produces a valid zip with the mandatory OOXML members', () {
      final path = pathFor('container.xlsx');
      Workbook(path)
        ..addWorksheet()
        ..close();

      final file = XlsxFile.read(path);
      for (final member in [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
      ]) {
        expect(file.hasMember(member), isTrue, reason: 'missing $member');
      }
    });

    test('writes the file only on close', () {
      final path = pathFor('deferred.xlsx');
      final workbook = Workbook(path)..addWorksheet();
      expect(File(path).existsSync(), isFalse);
      workbook.close();
      expect(File(path).existsSync(), isTrue);
    });
  });

  group('cell writes', () {
    test('writeString stores the value in the shared string table', () {
      final path = pathFor('string.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeString(0, 0, 'Report');
      workbook.close();

      final file = XlsxFile.read(path);
      expect(file.sharedStrings, contains('Report'));
      expect(cellValue(file.sheet(1), 'A1', file.sharedStrings), 'Report');
    });

    test('writeString round-trips non-ASCII UTF-8 text', () {
      final path = pathFor('unicode.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeString(0, 0, 'Grüße café αβγ 日本語');
      workbook.close();

      final file = XlsxFile.read(path);
      expect(
        cellValue(file.sheet(1), 'A1', file.sharedStrings),
        'Grüße café αβγ 日本語',
      );
    });

    test('writeNumber writes integers at the right cell reference', () {
      final path = pathFor('int.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeNumber(1, 1, 42);
      workbook.close();

      final file = XlsxFile.read(path);
      expect(cellValue(file.sheet(1), 'B2', file.sharedStrings), 42);
    });

    test('writeNumber writes doubles', () {
      final path = pathFor('double.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeNumber(0, 0, 123.456);
      workbook.close();

      final file = XlsxFile.read(path);
      expect(cellValue(file.sheet(1), 'A1', file.sharedStrings), 123.456);
    });

    test('writeBool writes true and false as boolean cells', () {
      final path = pathFor('bool.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet()
        ..writeBool(0, 0, true)
        ..writeBool(0, 1, false);
      workbook.close();

      final file = XlsxFile.read(path);
      expect(cell(file.sheet(1), 'A1')!.getAttribute('t'), 'b');
      expect(cellValue(file.sheet(1), 'A1', file.sharedStrings), true);
      expect(cellValue(file.sheet(1), 'B1', file.sharedStrings), false);
    });

    test('writeFormula stores the formula without the leading =', () {
      final path = pathFor('formula.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeFormula(0, 0, '=SUM(B1:B10)');
      workbook.close();

      final file = XlsxFile.read(path);
      expect(cellFormula(file.sheet(1), 'A1'), 'SUM(B1:B10)');
    });

    test('writeDateTime writes the correct 1900-system serial for a date', () {
      final path = pathFor('date.xlsx');
      final workbook = Workbook(path);
      final dateFormat = workbook.addFormat()..numberFormat('yyyy-mm-dd');
      workbook.addWorksheet().writeDateTime(
        0,
        0,
        DateTime(2026, 7, 17),
        dateFormat,
      );
      workbook.close();

      final expectedSerial = DateTime.utc(
        2026,
        7,
        17,
      ).difference(DateTime.utc(1899, 12, 30)).inDays;
      final file = XlsxFile.read(path);
      expect(
        cellValue(file.sheet(1), 'A1', file.sharedStrings),
        expectedSerial,
      );
    });

    test('writeDateTime encodes the time as the fractional part', () {
      final path = pathFor('datetime.xlsx');
      final workbook = Workbook(path);
      final format = workbook.addFormat()..numberFormat('yyyy-mm-dd hh:mm');
      workbook.addWorksheet().writeDateTime(
        0,
        0,
        DateTime(2026, 7, 17, 12, 30),
        format,
      );
      workbook.close();

      final wholeDay = DateTime.utc(
        2026,
        7,
        17,
      ).difference(DateTime.utc(1899, 12, 30)).inDays;
      final expected = wholeDay + (12 * 3600 + 30 * 60) / 86400.0;
      final file = XlsxFile.read(path);
      final value = cellValue(file.sheet(1), 'A1', file.sharedStrings) as num;
      expect(value, closeTo(expected, 1e-9));
    });

    test('writeUrl writes a hyperlink cell', () {
      final path = pathFor('url.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeUrl(0, 0, 'https://dart.dev/');
      workbook.close();

      final file = XlsxFile.read(path);
      // The display text is stored like any string; the link lives in the
      // sheet relationships.
      expect(
        cellValue(file.sheet(1), 'A1', file.sharedStrings),
        'https://dart.dev/',
      );
      expect(file.hasMember('xl/worksheets/_rels/sheet1.xml.rels'), isTrue);
    });

    test('writeBlank with a format records a styled empty cell', () {
      final path = pathFor('blank.xlsx');
      final workbook = Workbook(path);
      final format = workbook.addFormat()..backgroundColor(0xFF0000);
      workbook.addWorksheet().writeBlank(2, 2, format);
      workbook.close();

      final file = XlsxFile.read(path);
      final c = cell(file.sheet(1), 'C3');
      expect(c, isNotNull);
      expect(c!.getAttribute('s'), isNotNull);
      expect(c.findElements('v'), isEmpty);
    });
  });

  group('layout', () {
    test('addWorksheet names the sheet and lists it in the workbook', () {
      final path = pathFor('named.xlsx');
      final workbook = Workbook(path)..addWorksheet('Revenue');
      workbook.close();

      final file = XlsxFile.read(path);
      final names = file.workbook
          .findAllElements('sheet')
          .map((s) => s.getAttribute('name'))
          .toList();
      expect(names, ['Revenue']);
    });

    test('supports multiple worksheets', () {
      final path = pathFor('multi.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet('First').writeString(0, 0, 'a');
      workbook.addWorksheet('Second').writeString(0, 0, 'b');
      workbook.close();

      final file = XlsxFile.read(path);
      expect(file.hasMember('xl/worksheets/sheet1.xml'), isTrue);
      expect(file.hasMember('xl/worksheets/sheet2.xml'), isTrue);
      final names = file.workbook
          .findAllElements('sheet')
          .map((s) => s.getAttribute('name'))
          .toList();
      expect(names, ['First', 'Second']);
    });

    test('mergeRange emits a mergeCell over the range', () {
      final path = pathFor('merge.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().mergeRange(0, 0, 0, 3, 'Title');
      workbook.close();

      final file = XlsxFile.read(path);
      final merges = file
          .sheet(1)
          .findAllElements('mergeCell')
          .map((m) => m.getAttribute('ref'))
          .toList();
      expect(merges, contains('A1:D1'));
      expect(cellValue(file.sheet(1), 'A1', file.sharedStrings), 'Title');
    });

    test('freezePanes emits a frozen pane split', () {
      final path = pathFor('freeze.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().freezePanes(1, 0);
      workbook.close();

      final file = XlsxFile.read(path);
      final pane = file.sheet(1).findAllElements('pane').first;
      expect(pane.getAttribute('ySplit'), '1');
      expect(pane.getAttribute('state'), 'frozen');
    });

    test('setColumn sets the column width', () {
      final path = pathFor('colwidth.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().setColumn(0, 2, 20);
      workbook.close();

      final file = XlsxFile.read(path);
      final col = file.sheet(1).findAllElements('col').first;
      expect(col.getAttribute('min'), '1');
      expect(col.getAttribute('max'), '3');
      // Excel pads the requested width by a sub-unit amount for the default
      // font, so the stored value is slightly above the requested 20.
      expect(double.parse(col.getAttribute('width')!), closeTo(20, 1));
    });

    test('setColumnWidth sets a single column', () {
      final path = pathFor('singlecol.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().setColumnWidth(1, 30);
      workbook.close();

      final file = XlsxFile.read(path);
      final col = file.sheet(1).findAllElements('col').first;
      expect(col.getAttribute('min'), '2');
      expect(col.getAttribute('max'), '2');
      expect(double.parse(col.getAttribute('width')!), closeTo(30, 1));
    });

    test('setRow sets the row height', () {
      final path = pathFor('rowheight.xlsx');
      final workbook = Workbook(path);
      final sheet = workbook.addWorksheet()..setRow(0, 40);
      sheet.writeString(0, 0, 'tall');
      workbook.close();

      final file = XlsxFile.read(path);
      final row = file
          .sheet(1)
          .findAllElements('row')
          .firstWhere((r) => r.getAttribute('r') == '1');
      expect(double.parse(row.getAttribute('ht')!), closeTo(40, 0.001));
      expect(row.getAttribute('customHeight'), '1');
    });
  });

  group('formats', () {
    XmlXfProbe probe(String name, void Function(Format) configure) {
      final path = pathFor(name);
      final workbook = Workbook(path);
      final format = workbook.addFormat();
      configure(format);
      workbook.addWorksheet().writeString(0, 0, 'x', format);
      workbook.close();
      final file = XlsxFile.read(path);
      final index = cellStyleIndex(file.sheet(1), 'A1')!;
      return XmlXfProbe(file, cellXf(file.styles, index));
    }

    test('bold sets a bold font on the cell', () {
      final p = probe('bold.xlsx', (f) => f.bold());
      expect(fontFor(p.file.styles, p.xf).findElements('b'), isNotEmpty);
    });

    test('italic sets an italic font', () {
      final p = probe('italic.xlsx', (f) => f.italic());
      expect(fontFor(p.file.styles, p.xf).findElements('i'), isNotEmpty);
    });

    test('underline sets an underline', () {
      final p = probe('underline.xlsx', (f) => f.underline());
      expect(fontFor(p.file.styles, p.xf).findElements('u'), isNotEmpty);
    });

    test('fontName and fontSize are applied', () {
      final p = probe(
        'font.xlsx',
        (f) => f.fontName('Courier New').fontSize(18),
      );
      final font = fontFor(p.file.styles, p.xf);
      expect(
        font.findElements('name').first.getAttribute('val'),
        'Courier New',
      );
      expect(font.findElements('sz').first.getAttribute('val'), '18');
    });

    test('fontColor sets an ARGB font color', () {
      final p = probe('fontcolor.xlsx', (f) => f.fontColor(0xFF0000));
      final font = fontFor(p.file.styles, p.xf);
      expect(font.findElements('color').first.getAttribute('rgb'), 'FFFF0000');
    });

    test('backgroundColor sets a solid fill', () {
      final p = probe('bg.xlsx', (f) => f.backgroundColor(0x4472C4));
      final fill = fillFor(p.file.styles, p.xf);
      final patternFill = fill.findElements('patternFill').first;
      expect(patternFill.getAttribute('patternType'), 'solid');
      expect(
        patternFill.findElements('fgColor').first.getAttribute('rgb'),
        'FF4472C4',
      );
    });

    test('numberFormat registers a custom format code and applies it', () {
      final p = probe('numfmt.xlsx', (f) => f.numberFormat(r'$#,##0.00'));
      expect(p.xf.getAttribute('applyNumberFormat'), '1');
      final id = int.parse(p.xf.getAttribute('numFmtId')!);
      expect(id, greaterThanOrEqualTo(164));
      expect(numberFormatCode(p.file.styles, id), r'$#,##0.00');
    });

    test('align sets horizontal alignment', () {
      final p = probe('align.xlsx', (f) => f.align(Alignment.center));
      expect(
        p.xf.findElements('alignment').first.getAttribute('horizontal'),
        'center',
      );
    });

    test('verticalAlign sets vertical alignment', () {
      final p = probe(
        'valign.xlsx',
        (f) => f.verticalAlign(VerticalAlignment.top),
      );
      expect(
        p.xf.findElements('alignment').first.getAttribute('vertical'),
        'top',
      );
    });

    test('textWrap sets wrapText', () {
      final p = probe('wrap.xlsx', (f) => f.textWrap());
      expect(
        p.xf.findElements('alignment').first.getAttribute('wrapText'),
        '1',
      );
    });

    test('border sets a thin border on all sides', () {
      final p = probe('border.xlsx', (f) => f.border());
      final border = borderFor(p.file.styles, p.xf);
      for (final side in ['left', 'right', 'top', 'bottom']) {
        expect(
          border.findElements(side).first.getAttribute('style'),
          'thin',
          reason: '$side border',
        );
      }
    });

    test('borderColor sets a colored border', () {
      final p = probe(
        'bordercolor.xlsx',
        (f) => f.border(Border.medium).borderColor(0x00FF00),
      );
      final border = borderFor(p.file.styles, p.xf);
      final left = border.findElements('left').first;
      expect(left.getAttribute('style'), 'medium');
      expect(left.findElements('color').first.getAttribute('rgb'), 'FF00FF00');
    });

    test('format setters chain by returning the same instance', () {
      final path = pathFor('chain.xlsx');
      final workbook = Workbook(path);
      final format = workbook.addFormat();
      expect(identical(format.bold(), format), isTrue);
      expect(identical(format.italic().fontSize(12), format), isTrue);
      workbook.close();
    });
  });

  group('constant memory mode', () {
    test('writes many rows and remains a valid file with the last row', () {
      final path = pathFor('big.xlsx');
      final workbook = Workbook.constantMemory(path);
      final sheet = workbook.addWorksheet('Big');
      const rowCount = 5000;
      for (var row = 0; row < rowCount; row++) {
        sheet.writeString(row, 0, 'row$row');
        sheet.writeNumber(row, 1, row * 1.5);
      }
      workbook.close();

      final file = XlsxFile.read(path);
      expect(file.hasMember('xl/worksheets/sheet1.xml'), isTrue);
      final sheetXml = file.sheet(1);
      expect(
        cellValue(sheetXml, 'A$rowCount', file.sharedStrings),
        'row${rowCount - 1}',
      );
      expect(
        cellValue(sheetXml, 'B$rowCount', file.sharedStrings),
        (rowCount - 1) * 1.5,
      );
    });
  });

  group('error handling and lifecycle', () {
    test('writing after close throws StateError', () {
      final path = pathFor('closed.xlsx');
      final workbook = Workbook(path);
      final sheet = workbook.addWorksheet();
      workbook.close();
      expect(() => sheet.writeString(0, 0, 'late'), throwsStateError);
      expect(() => workbook.addWorksheet(), throwsStateError);
      expect(() => workbook.addFormat(), throwsStateError);
    });

    test('close is idempotent', () {
      final path = pathFor('double.xlsx');
      final workbook = Workbook(path)..addWorksheet();
      workbook.close();
      expect(workbook.isClosed, isTrue);
      expect(workbook.close, returnsNormally);
    });

    test('an invalid worksheet name throws XlsxWriterException', () {
      final path = pathFor('badname.xlsx');
      final workbook = Workbook(path);
      addTearDown(workbook.close);
      expect(
        () => workbook.addWorksheet('has:invalid?chars'),
        throwsA(isA<XlsxWriterException>()),
      );
    });

    test('a duplicate worksheet name throws XlsxWriterException', () {
      final path = pathFor('dupname.xlsx');
      final workbook = Workbook(path)..addWorksheet('Data');
      addTearDown(workbook.close);
      expect(
        () => workbook.addWorksheet('Data'),
        throwsA(isA<XlsxWriterException>()),
      );
    });

    test('an over-long string throws XlsxWriterException', () {
      final path = pathFor('longstring.xlsx');
      final workbook = Workbook(path);
      final sheet = workbook.addWorksheet();
      addTearDown(workbook.close);
      expect(
        () => sheet.writeString(0, 0, 'a' * 40000),
        throwsA(isA<XlsxWriterException>()),
      );
    });

    test('a negative row or column throws ArgumentError', () {
      final path = pathFor('negative.xlsx');
      final workbook = Workbook(path);
      final sheet = workbook.addWorksheet();
      addTearDown(workbook.close);
      expect(() => sheet.writeString(-1, 0, 'x'), throwsArgumentError);
      expect(() => sheet.writeNumber(0, -1, 1), throwsArgumentError);
    });

    test('XlsxWriterException exposes a code and a human-readable message', () {
      final exception = XlsxWriterException(2);
      expect(exception.code, 2);
      expect(exception.message, isNotEmpty);
      expect(exception.toString(), contains(exception.message));
    });
  });

  group('writeRow', () {
    test('dispatches each value by its runtime type', () {
      final path = pathFor('writerow.xlsx');
      final workbook = Workbook(path);
      final date = workbook.addFormat().numberFormat('yyyy-mm-dd');
      workbook.addWorksheet().writeRow(
        0,
        ['Widget', 12, 4.99, true, null, DateTime.utc(2026, 7, 20)],
        dateFormat: date,
      );
      workbook.close();

      final file = XlsxFile.read(path);
      final strings = file.sharedStrings;
      expect(cellValue(file.sheet(1), 'A1', strings), 'Widget');
      expect(cellValue(file.sheet(1), 'B1', strings), 12);
      expect(cellValue(file.sheet(1), 'C1', strings), 4.99);
      expect(cellValue(file.sheet(1), 'D1', strings), true);
      // E1 is blank: it has no value. A DateTime stores as a number (a serial).
      expect(cellValue(file.sheet(1), 'E1', strings), isNull);
      expect(cellValue(file.sheet(1), 'F1', strings), isA<num>());
    });

    test('honours startCol', () {
      final path = pathFor('writerow_startcol.xlsx');
      final workbook = Workbook(path);
      workbook.addWorksheet().writeRow(0, ['x', 'y'], startCol: 2);
      workbook.close();

      final file = XlsxFile.read(path);
      expect(cellValue(file.sheet(1), 'C1', file.sharedStrings), 'x');
      expect(cellValue(file.sheet(1), 'D1', file.sharedStrings), 'y');
    });

    test('a DateTime without a dateFormat is rejected', () {
      final workbook = Workbook(pathFor('writerow_nodate.xlsx'));
      final sheet = workbook.addWorksheet();
      expect(
        () => sheet.writeRow(0, [DateTime.utc(2026, 1, 1)]),
        throwsArgumentError,
      );
      workbook.close();
    });

    test('an unsupported type is rejected, naming the column', () {
      final workbook = Workbook(pathFor('writerow_badtype.xlsx'));
      final sheet = workbook.addWorksheet();
      expect(
        () => sheet.writeRow(0, ['ok', Object()]),
        throwsA(isA<ArgumentError>()),
      );
      workbook.close();
    });
  });
}

/// A resolved cell format record together with the file it came from, so a
/// format test can follow the `fontId`/`fillId`/`borderId` links.
class XmlXfProbe {
  XmlXfProbe(this.file, this.xf);

  final XlsxFile file;
  final XmlElement xf;
}
