import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:xlsxwriter/xlsxwriter.dart';

import 'xlsx_reader.dart';

// A valid 2x2 PNG, generated once and inlined so the test needs no asset.
const _pngBytes = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,2,0,0,0,2,8,2,0,0,0,253,212,154,115,0,0,0,15,73,68,65,84,120,156,99,248,207,192,0,68,16,12,0,26,242,3,253,95,87,196,200,0,0,0,0,73,69,78,68,174,66,96,130];

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('xlsximg'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });
  String pathFor(String n) => '${tempDir.path}/$n';

  test('insertImage embeds the image as a media part', () {
    final path = pathFor('image.xlsx');
    final workbook = Workbook(path);
    workbook
        .addWorksheet()
        .insertImage(0, 0, Uint8List.fromList(_pngBytes));
    workbook.close();

    final file = XlsxFile.read(path);
    // libxlsxwriter writes the picture into xl/media/ and wires up a drawing.
    final media = file.memberNames.where((n) => n.startsWith('xl/media/'));
    expect(media, isNotEmpty, reason: 'the image should be an embedded part');
    expect(
      file.memberNames.any((n) => n.startsWith('xl/drawings/')),
      isTrue,
      reason: 'a drawing relationship should be written',
    );
  });

  test('insertImage rejects empty bytes', () {
    final workbook = Workbook(pathFor('empty.xlsx'));
    final sheet = workbook.addWorksheet();
    expect(
      () => sheet.insertImage(0, 0, Uint8List(0)),
      throwsArgumentError,
    );
    workbook.close();
  });

  test('insertImage rejects bytes that are not an image', () {
    final workbook = Workbook(pathFor('notimage.xlsx'));
    final sheet = workbook.addWorksheet();
    expect(
      () => sheet.insertImage(0, 0, Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<XlsxWriterException>()),
    );
    workbook.close();
  });
}
