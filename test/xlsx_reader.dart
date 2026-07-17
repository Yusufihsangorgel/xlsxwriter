// Test-only helper: opens an .xlsx (a zip of XML parts) with the pure-Dart
// `archive` package and parses the parts with `xml`, so the tests can assert on
// the real bytes libxlsxwriter produced without any native or Python
// dependency.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A parsed view over the parts of an `.xlsx` file.
class XlsxFile {
  XlsxFile._(this._parts);

  /// Reads and unzips the `.xlsx` at [path].
  factory XlsxFile.read(String path) {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final parts = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile) {
        parts[file.name] = file.readBytes() ?? Uint8List(0);
      }
    }
    return XlsxFile._(parts);
  }

  final Map<String, Uint8List> _parts;

  /// The names of every member (file) in the zip container.
  Iterable<String> get memberNames => _parts.keys;

  /// Whether the container has a member named [name].
  bool hasMember(String name) => _parts.containsKey(name);

  /// The UTF-8 text of member [name].
  String text(String name) {
    final data = _parts[name];
    if (data == null) {
      throw StateError('Missing xlsx part: $name');
    }
    return utf8.decode(data);
  }

  /// The parsed XML of member [name].
  XmlDocument xml(String name) => XmlDocument.parse(text(name));

  /// The XML of worksheet [index] (1-based), `xl/worksheets/sheetN.xml`.
  XmlDocument sheet(int index) => xml('xl/worksheets/sheet$index.xml');

  /// The XML of `xl/styles.xml`.
  XmlDocument get styles => xml('xl/styles.xml');

  /// The XML of `xl/workbook.xml`.
  XmlDocument get workbook => xml('xl/workbook.xml');

  /// The shared-string table, in index order. Empty if the workbook has no
  /// `xl/sharedStrings.xml` (as in constant-memory mode, where strings are
  /// stored inline in the sheet instead).
  List<String> get sharedStrings {
    if (!hasMember('xl/sharedStrings.xml')) return const [];
    final doc = xml('xl/sharedStrings.xml');
    return doc
        .findAllElements('si')
        .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
        .toList();
  }
}

/// The `<c>` cell element with reference [ref] (such as `A1`) in [sheet], or
/// `null` if that cell was not written.
XmlElement? cell(XmlDocument sheet, String ref) {
  for (final c in sheet.findAllElements('c')) {
    if (c.getAttribute('r') == ref) return c;
  }
  return null;
}

/// The resolved display value of the cell at [ref] in [sheet].
///
/// Shared-string and inline-string cells return their [String] text (using
/// [strings] for the shared table), boolean cells return a [bool], and numeric
/// cells return a [num]. Returns `null` if the cell or its value is absent.
Object? cellValue(XmlDocument sheet, String ref, List<String> strings) {
  final c = cell(sheet, ref);
  if (c == null) return null;
  final type = c.getAttribute('t');
  if (type == 's') {
    final index = int.parse(c.findElements('v').first.innerText);
    return strings[index];
  }
  if (type == 'inlineStr') {
    return c
        .findElements('is')
        .first
        .findAllElements('t')
        .map((t) => t.innerText)
        .join();
  }
  final v = c.findElements('v').firstOrNull;
  if (v == null) return null;
  if (type == 'b') return v.innerText == '1';
  return num.parse(v.innerText);
}

/// The text of the `<f>` formula element of the cell at [ref], or `null`.
String? cellFormula(XmlDocument sheet, String ref) =>
    cell(sheet, ref)?.findElements('f').firstOrNull?.innerText;

/// The `s` (style index) attribute of the cell at [ref], or `null`.
int? cellStyleIndex(XmlDocument sheet, String ref) {
  final s = cell(sheet, ref)?.getAttribute('s');
  return s == null ? null : int.parse(s);
}

/// The `<xf>` cell format record at [index] within `<cellXfs>` of [styles].
XmlElement cellXf(XmlDocument styles, int index) =>
    styles.findAllElements('cellXfs').first.findElements('xf').elementAt(index);

/// The `<font>` referenced by the `fontId` of cell format [xf].
XmlElement fontFor(XmlDocument styles, XmlElement xf) => styles
    .findAllElements('fonts')
    .first
    .findElements('font')
    .elementAt(int.parse(xf.getAttribute('fontId')!));

/// The `<fill>` referenced by the `fillId` of cell format [xf].
XmlElement fillFor(XmlDocument styles, XmlElement xf) => styles
    .findAllElements('fills')
    .first
    .findElements('fill')
    .elementAt(int.parse(xf.getAttribute('fillId')!));

/// The `<border>` referenced by the `borderId` of cell format [xf].
XmlElement borderFor(XmlDocument styles, XmlElement xf) => styles
    .findAllElements('borders')
    .first
    .findElements('border')
    .elementAt(int.parse(xf.getAttribute('borderId')!));

/// The `formatCode` of the custom number format with id [numFmtId], or `null`.
String? numberFormatCode(XmlDocument styles, int numFmtId) {
  for (final nf in styles.findAllElements('numFmt')) {
    if (nf.getAttribute('numFmtId') == '$numFmtId') {
      return nf.getAttribute('formatCode');
    }
  }
  return null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
