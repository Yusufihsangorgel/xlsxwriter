// Generates doc/anatomy.svg and doc/anatomy.png, the figure in the README's
// "How it works" section.
//
//   dart run tool/anatomy_figure.dart
//
// Nothing in the drawing is typed in by hand. The tool writes the README's
// headline loop twice, at 1,000 and at 100,000 rows, then reads the ZIP
// central directory of each finished .xlsx and plots the size of every part.
// The claim it draws is that eight of the nine parts are byte-identical
// between the two files and the ninth, the worksheet, carries the growth. If a
// run finds that untrue it writes nothing and exits 1, because at that point
// the picture would be making a claim the package no longer supports.
//
// The ZIP directory is parsed here rather than with `archive` so that the tool
// stays outside the dev dependencies, and because the two numbers it needs,
// the compressed and uncompressed size of each entry, are fields of the
// central directory header.
//
// One line of the figure is not a measurement: the second footer line, which
// says the worksheet is written in document order and streamed to a temp file.
// That is the mechanism described in the README's "How it works" section and
// in tool/mechanism_diagram.dart. Everything else on the canvas, every number
// and every bar, comes out of the two archives this run produced.
//
// Same rasterizing arrangement, palette and serif as tool/benchmark_chart.dart
// and tool/mechanism_diagram.dart, because pub.dev shows the three screenshots
// side by side on the package page.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xlsxwriter/xlsxwriter.dart';

/// The two sheet sizes to write and compare. A hundredfold apart, so that a
/// part which does not move is unmistakably fixed rather than slow-growing.
const _smallRows = 1000;
const _largeRows = 100000;

/// The part that is allowed to differ between the two archives. Every other
/// entry has to match to the byte or the figure does not get written.
const _sheetPart = 'xl/worksheets/sheet1.xml';

// Canvas. Rendered at 2x, so the PNG lands at 1600x1500.
const _width = 800.0;
const _height = 750.0;
const _scale = 2;

/// Flat artwork this size lands well under this once quantized. A jump past it
/// means something picked up a gradient; the PNG ships inside the published
/// archive.
const _pngBudgetBytes = 80 * 1024;

// Plot area. The left margin holds the longest part name in 12px monospace.
const _plotLeft = 268.0;
const _plotRight = 770.0;
const _plotTop = 118.0;
const _rowPitch = 56.0;

/// Log axis bounds, in bytes: two decades below the smallest part and one
/// above the largest, so no bar starts at zero width or runs off the edge.
const _axisMinPow = 2;
const _axisMaxPow = 8;

/// Where the "same bytes in both files" bracket sits, as a fraction of the
/// plot width. Clear of the longest bar among the parts it brackets.
const _bracketFraction = 0.5;

const _paper = '#FAF6F0';
const _ink = '#1A1A1A';
const _muted = '#6B6B6B';
const _grid = '#E4DCD0';
const _line = '#4A4A4A';
const _blue = '#1F77B4';
const _blueFill = '#DCEAF6';
const _orange = '#E4610F';
const _orangeFill = '#FBE7D8';

const _serif = "Georgia, 'Times New Roman', Times, serif";
const _mono = "'SF Mono', 'DejaVu Sans Mono', Menlo, Consolas, monospace";

void main() {
  if (!Directory('doc').existsSync()) {
    stderr.writeln(
      'run this from the package root: doc/ not found in '
      '${Directory.current.path}',
    );
    exit(1);
  }

  final small = _measure(_smallRows);
  final large = _measure(_largeRows);

  _report(small, large);

  final complaint = _checkClaim(small, large);
  if (complaint != null) {
    stderr
      ..writeln('not drawing the figure: $complaint')
      ..writeln(
        'the picture says one part grows and the rest hold still. Re-measure '
        'before changing it.',
      );
    exitCode = 1;
    return;
  }

  final svgFile = File('doc/anatomy.svg')
    ..writeAsStringSync(_buildSvg(small, large));
  stdout.writeln('wrote ${svgFile.path}');

  const png = 'doc/anatomy.png';
  final rsvg = _which('rsvg-convert');
  if (rsvg == null) {
    stdout.writeln(
      'rsvg-convert not found; install it (brew install librsvg) or run:\n'
      '  rsvg-convert -z $_scale doc/anatomy.svg -o $png',
    );
    return;
  }
  _run(rsvg, ['-z', '$_scale', 'doc/anatomy.svg', '-o', png]);
  var bytes = File(png).lengthSync();
  stdout.writeln(
    'wrote $png (${_width.round() * _scale}x${_height.round() * _scale}, '
    '${_kib(bytes)})',
  );

  final magick = _which('magick') ?? _which('convert');
  if (magick == null) {
    stdout.writeln(
      'ImageMagick not found; the PNG is uncompressed truecolour. Install it\n'
      '(brew install imagemagick) and re-run to quantize, or run:\n'
      '  magick $png -strip -colors 64 PNG8:$png',
    );
  } else {
    final quantized = '$png.quantized';
    _run(magick, [png, '-strip', '-colors', '64', 'PNG8:$quantized']);
    final quantizedBytes = File(quantized).lengthSync();
    if (quantizedBytes < bytes) {
      File(quantized).renameSync(png);
      stdout.writeln(
        'quantized to 64 colours: ${_kib(bytes)} -> ${_kib(quantizedBytes)}',
      );
      bytes = quantizedBytes;
    } else {
      File(quantized).deleteSync();
      stdout.writeln('quantizing did not help; kept the truecolour PNG');
    }
  }

  if (bytes > _pngBudgetBytes) {
    stderr.writeln(
      'WARNING: $png is ${_kib(bytes)}, over the ${_kib(_pngBudgetBytes)} '
      'budget. It ships inside the published archive.',
    );
  }
}

/// Writes the README's headline loop at [rows] rows and returns what came out,
/// part by part.
_Archive _measure(int rows) {
  final dir = Directory.systemTemp.createTempSync('xlsxwriter-anatomy');
  try {
    final path = '${dir.path}/export-$rows.xlsx';
    final workbook = Workbook.constantMemory(path);
    final sheet = workbook.addWorksheet('Export');
    sheet.writeRow(0, ['id', 'label', 'amount']);
    for (var row = 1; row <= rows; row++) {
      sheet.writeRow(row, ['SKU-$row', 'Item $row', row * 1.5]);
    }
    workbook.close();

    final bytes = File(path).readAsBytesSync();
    return _Archive(rows, bytes.length, _readCentralDirectory(bytes));
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// The reason the figure must not be drawn, or null if the measurement still
/// says what the figure says.
String? _checkClaim(_Archive small, _Archive large) {
  final smallNames = small.parts.map((p) => p.name).toList();
  final largeNames = large.parts.map((p) => p.name).toList();
  if (!_sameOrder(smallNames, largeNames)) {
    return 'the two archives hold different parts: $smallNames against '
        '$largeNames';
  }
  if (!smallNames.contains(_sheetPart)) {
    return 'no $_sheetPart in the archive; the worksheet part was renamed';
  }
  for (var i = 0; i < smallNames.length; i++) {
    if (smallNames[i] == _sheetPart) continue;
    final a = small.parts[i], b = large.parts[i];
    if (a.uncompressed != b.uncompressed) {
      return '${a.name} is ${a.uncompressed} bytes at ${small.rows} rows and '
          '${b.uncompressed} at ${large.rows}, so it is not fixed overhead';
    }
  }
  if (large.part(_sheetPart).uncompressed <=
      small.part(_sheetPart).uncompressed) {
    return '$_sheetPart did not grow between ${small.rows} and ${large.rows} '
        'rows';
  }
  return null;
}

void _report(_Archive small, _Archive large) {
  stdout.writeln(
    'part'.padRight(30) +
        '${small.rows} rows'.padLeft(14) +
        '${large.rows} rows'.padLeft(14),
  );
  for (final part in large.parts) {
    stdout.writeln(
      part.name.padRight(30) +
          small.part(part.name).uncompressed.toString().padLeft(14) +
          part.uncompressed.toString().padLeft(14),
    );
  }
  stdout.writeln(
    'uncompressed total'.padRight(30) +
        small.totalUncompressed.toString().padLeft(14) +
        large.totalUncompressed.toString().padLeft(14),
  );
  stdout.writeln(
    '.xlsx on disk'.padRight(30) +
        small.fileBytes.toString().padLeft(14) +
        large.fileBytes.toString().padLeft(14),
  );
}

String _buildSvg(_Archive small, _Archive large) {
  final parts = [...large.parts]
    ..sort((a, b) => b.uncompressed.compareTo(a.uncompressed));
  final plotWidth = _plotRight - _plotLeft;
  final plotBottom = _plotTop + parts.length * _rowPitch;

  double x(int bytes) {
    final decades = (_axisMaxPow - _axisMinPow).toDouble();
    final t = (_log10(bytes.toDouble()) - _axisMinPow) / decades;
    return _plotLeft + t.clamp(0.0, 1.0) * plotWidth;
  }

  final b = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_width.round()}" height="${_height.round()}" '
      'viewBox="0 0 ${_width.round()} ${_height.round()}">',
    )
    ..writeln('  <rect width="$_width" height="$_height" fill="$_paper"/>')
    ..writeln(
      _text(
        _width / 2,
        42,
        'One part of the .xlsx grows. The other '
        '${_word(parts.length - 1)} do not.',
        size: 18,
        weight: 'bold',
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        66,
        'the same export written at ${_grouped(small.rows)} and '
        '${_grouped(large.rows)} rows, every part measured uncompressed',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    );

  // Legend, centred under the subtitle.
  const legendY = 88.0;
  b
    ..writeln(_swatch(289, legendY, _blueFill, _blue))
    ..writeln(
      _text(
        309,
        legendY + 10,
        '${_grouped(small.rows)} rows',
        size: 12,
        fill: _muted,
      ),
    )
    ..writeln(_swatch(417, legendY, _blue, _blue))
    ..writeln(
      _text(
        437,
        legendY + 10,
        '${_grouped(large.rows)} rows',
        size: 12,
        fill: _muted,
      ),
    );

  // Decade gridlines and their labels.
  for (var p = _axisMinPow; p <= _axisMaxPow; p++) {
    final gx = _f(x(_pow10(p)));
    b
      ..writeln(
        '  <line x1="$gx" y1="$_plotTop" x2="$gx" y2="${_f(plotBottom)}" '
        'stroke="$_grid" stroke-width="1"/>',
      )
      ..writeln(
        _text(
          x(_pow10(p)),
          plotBottom + 22,
          _bytes(_pow10(p)),
          size: 11,
          fill: _muted,
          anchor: 'middle',
        ),
      );
  }

  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    final before = small.part(part.name).uncompressed;
    final after = part.uncompressed;
    final grew = part.name == _sheetPart;
    final rowTop = _plotTop + i * _rowPitch;

    b
      ..writeln(
        _code(_plotLeft - 14, rowTop + 32, part.name, anchor: 'end', size: 12),
      )
      ..writeln(_bar(_plotLeft, rowTop + 12, x(before), _blueFill, _blue))
      ..writeln(
        _bar(
          _plotLeft,
          rowTop + 28,
          x(after),
          grew ? _orange : _blue,
          grew ? _orange : _blue,
        ),
      );

    if (grew) {
      // The one row where the two bars differ, so each gets its own number.
      b
        ..writeln(
          _code(
            x(before) + 10,
            rowTop + 22,
            _bytes(before),
            fill: _blue,
            size: 12,
          ),
        )
        ..writeln(
          _code(
            x(after) - 10,
            rowTop + 38,
            _bytes(after),
            fill: _paper,
            anchor: 'end',
            size: 12,
          ),
        )
        ..writeln(
          _text(
            _plotRight,
            rowTop + 38,
            '${(after / before).toStringAsFixed(1)}x',
            size: 12,
            weight: 'bold',
            fill: _orange,
            anchor: 'end',
          ),
        );
    } else {
      // Both bars are the same length, so one number covers the pair.
      b.writeln(_code(x(after) + 10, rowTop + 30, _bytes(after), fill: _muted));
    }
  }

  // The bracket over every part that held still, which is the whole point.
  final bracketX = _plotLeft + _bracketFraction * plotWidth;
  final bracketTop = _plotTop + _rowPitch + 10;
  final bracketBottom = _plotTop + parts.length * _rowPitch - 4;
  b
    ..writeln(
      '  <path d="M ${_f(bracketX + 8)} ${_f(bracketTop)} '
      'L ${_f(bracketX)} ${_f(bracketTop)} '
      'L ${_f(bracketX)} ${_f(bracketBottom)} '
      'L ${_f(bracketX + 8)} ${_f(bracketBottom)}" fill="none" '
      'stroke="$_line" stroke-width="1.6"/>',
    )
    ..writeln(
      _text(
        bracketX + 18,
        (bracketTop + bracketBottom) / 2 - 5,
        'byte for byte the same',
        size: 13,
        weight: 'bold',
      ),
    )
    ..writeln(
      _text(
        bracketX + 18,
        (bracketTop + bracketBottom) / 2 + 13,
        'in both files: '
        '${_grouped(large.totalUncompressed - large.part(_sheetPart).uncompressed)}'
        ' B in total',
        size: 12,
        fill: _muted,
      ),
    );

  b.writeln(
    _text(
      _plotLeft + plotWidth / 2,
      plotBottom + 44,
      'uncompressed size of the part, log scale',
      size: 12,
      fill: _muted,
      anchor: 'middle',
    ),
  );

  // Footer: what the reader is meant to take away.
  final share =
      100 * large.part(_sheetPart).uncompressed / large.totalUncompressed;
  b
    ..writeln(
      '  <rect x="40" y="686" width="720" height="46" rx="8" '
      'fill="$_orangeFill" stroke="$_orange" stroke-width="1.2"/>',
    )
    ..writeln(
      _text(
        _width / 2,
        706,
        'At ${_grouped(large.rows)} rows the worksheet holds '
        '${share.toStringAsFixed(2)}% of the uncompressed bytes.',
        size: 13,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        724,
        'It is also the one part written in document order, which is what '
        'constant-memory mode streams to a temp file.',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    )
    ..writeln('</svg>');
  return b.toString();
}

// ---------------------------------------------------------------------------
// Reading the archive.

class _Part {
  _Part(this.name, this.compressed, this.uncompressed);

  final String name;
  final int compressed;
  final int uncompressed;
}

class _Archive {
  _Archive(this.rows, this.fileBytes, this.parts);

  final int rows;

  /// Size of the .xlsx on disk, deflated parts and directory together.
  final int fileBytes;
  final List<_Part> parts;

  int get totalUncompressed =>
      parts.fold(0, (sum, part) => sum + part.uncompressed);

  _Part part(String name) => parts.firstWhere((p) => p.name == name);
}

/// Every entry in a ZIP archive, read from the central directory at the end of
/// the file. Only the fields this figure plots are pulled out: the name, and
/// the two sizes.
List<_Part> _readCentralDirectory(Uint8List bytes) {
  const endSignature = 0x06054b50;
  const headerSignature = 0x02014b50;
  final data = ByteData.sublistView(bytes);

  // The end record is last, but a trailing comment can push it back, so scan
  // upwards from the earliest position it could occupy.
  var end = -1;
  for (var i = bytes.length - 22; i >= 0; i--) {
    if (data.getUint32(i, Endian.little) == endSignature) {
      end = i;
      break;
    }
  }
  if (end < 0) throw const FormatException('no ZIP end of central directory');

  final count = data.getUint16(end + 10, Endian.little);
  var offset = data.getUint32(end + 16, Endian.little);
  final parts = <_Part>[];
  for (var i = 0; i < count; i++) {
    if (data.getUint32(offset, Endian.little) != headerSignature) {
      throw FormatException('bad central directory header at $offset');
    }
    final compressed = data.getUint32(offset + 20, Endian.little);
    final uncompressed = data.getUint32(offset + 24, Endian.little);
    final nameLength = data.getUint16(offset + 28, Endian.little);
    final extraLength = data.getUint16(offset + 30, Endian.little);
    final commentLength = data.getUint16(offset + 32, Endian.little);
    parts.add(
      _Part(
        String.fromCharCodes(bytes, offset + 46, offset + 46 + nameLength),
        compressed,
        uncompressed,
      ),
    );
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return parts;
}

// ---------------------------------------------------------------------------
// Drawing helpers, shared in spirit with the other two tools.

String _bar(double left, double y, double right, String fill, String stroke) =>
    '  <rect x="${_f(left)}" y="${_f(y)}" width="${_f(right - left)}" '
    'height="12" rx="2" fill="$fill" stroke="$stroke" stroke-width="1"/>';

String _swatch(double x, double y, String fill, String stroke) =>
    '  <rect x="${_f(x)}" y="${_f(y)}" width="14" height="12" rx="2" '
    'fill="$fill" stroke="$stroke" stroke-width="1"/>';

String _text(
  double x,
  double y,
  String value, {
  required double size,
  String fill = _ink,
  String weight = 'normal',
  String anchor = 'start',
  String family = _serif,
}) =>
    '  <text x="${_f(x)}" y="${_f(y)}" font-family="$family" '
    'font-size="$size" font-weight="$weight" fill="$fill" '
    'text-anchor="$anchor">${_escape(value)}</text>';

String _code(
  double x,
  double y,
  String value, {
  String fill = _ink,
  String anchor = 'start',
  double size = 14,
}) => _text(x, y, value, size: size, fill: fill, anchor: anchor, family: _mono);

String _f(double v) => v.toStringAsFixed(1);

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Decimal, because the axis is decades. Small parts stay in raw bytes, which
/// is the honest unit for something under ten kilobytes.
String _bytes(int value) {
  if (value >= 1000000) {
    final mb = value / 1000000;
    if (mb == mb.roundToDouble()) return '${mb.round()} MB';
    return '${mb.toStringAsFixed(1)} MB';
  }
  if (value >= 10000 && value % 1000 == 0) return '${value ~/ 1000} kB';
  if (value >= 10000) return '${(value / 1000).round()} kB';
  if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000} kB';
  return '${_grouped(value)} B';
}

String _grouped(int value) {
  final digits = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

const _words = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
];

String _word(int n) => n < _words.length ? _words[n] : '$n';

String _kib(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KiB';

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _log10(double v) => math.log(v) / math.ln10;

int _pow10(int p) {
  var v = 1;
  for (var i = 0; i < p; i++) {
    v *= 10;
  }
  return v;
}

void _run(String executable, List<String> arguments) {
  final result = Process.runSync(executable, arguments);
  if (result.exitCode != 0) {
    stderr
      ..writeln('$executable failed with exit code ${result.exitCode}')
      ..writeln((result.stderr as String).trim());
    exit(result.exitCode);
  }
}

String? _which(String command) {
  final result = Process.runSync('which', [command]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}
