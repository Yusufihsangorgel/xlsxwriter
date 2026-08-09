// Generates doc/mechanism.svg and doc/mechanism.png, the diagram in the
// README's "How constant-memory writing works" section.
//
//   dart run tool/mechanism_diagram.dart
//
// Same rasterizing arrangement as tool/benchmark_chart.dart: `rsvg-convert`
// for the PNG, an optional ImageMagick pass to quantize it. The palette and
// the serif are shared with that chart on purpose, because pub.dev shows both
// screenshots side by side on the package page.
//
// The canvas is close to square. pub.dev fits a `screenshots:` entry into a
// 190x190 thumbnail rather than cropping it, and the wide version of this
// diagram arrived on the card as an unreadable strip.
import 'dart:io';

// Canvas. Rendered at 2x, so the PNG lands at 1360x1328.
const _width = 680.0;
const _height = 664.0;
const _scale = 2;

/// Flat artwork this size lands around 40 KB once quantized. A jump past this
/// means something picked up a gradient.
const _pngBudgetBytes = 80 * 1024;

// The vertical spine of stage boxes, and the annotation column beside it.
const _boxLeft = 78.0;
const _boxRight = 418.0;
const _noteLeft = 438.0;
// The gutter the "you cannot go back" arrow runs up.
const _returnX = 46.0;

const _paper = '#FAF6F0';
const _ink = '#1A1A1A';
const _muted = '#6B6B6B';
const _line = '#4A4A4A';
const _blue = '#1F77B4';
const _blueFill = '#DCEAF6';
const _green = '#2E7D32';
const _orange = '#E4610F';
const _orangeFill = '#FBE7D8';
const _red = '#C62828';

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

  final svgFile = File('doc/mechanism.svg')..writeAsStringSync(_buildSvg());
  stdout.writeln('wrote ${svgFile.path}');

  const png = 'doc/mechanism.png';
  final rsvg = _which('rsvg-convert');
  if (rsvg == null) {
    stdout.writeln(
      'rsvg-convert not found; install it (brew install librsvg) or run:\n'
      '  rsvg-convert -z $_scale doc/mechanism.svg -o $png',
    );
    return;
  }
  _run(rsvg, ['-z', '$_scale', 'doc/mechanism.svg', '-o', png]);
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

String _buildSvg() {
  final b = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_width.round()}" height="${_height.round()}" '
      'viewBox="0 0 ${_width.round()} ${_height.round()}">',
    )
    ..writeln('  <defs>')
    ..writeln(_arrowMarker('head', _line))
    ..writeln(_arrowMarker('headRed', _red))
    ..writeln('  </defs>')
    ..writeln('  <rect width="$_width" height="$_height" fill="$_paper"/>')
    ..writeln(
      _text(
        _width / 2,
        40,
        'Constant-memory mode: one row in RAM, the rest already on disk',
        size: 18,
        weight: 'bold',
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        64,
        'Both modes emit the same worksheet XML. They differ in how much of it '
        'they hold at once.',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    );

  // Stage 1: the loop you write.
  b
    ..writeln(_box(92, 206, _line))
    ..writeln(_boxTitle(116, 'your loop'))
    // Row indices are 0-based and the XML is 1-based, which is why the temp
    // file below holds r="1" and r="2" while the loop is on writeRow(2).
    ..writeln(_code(_boxLeft + 22, 144, 'writeRow(0, ...)', fill: _muted))
    ..writeln(_code(_boxLeft + 22, 166, 'writeRow(1, ...)', fill: _muted))
    ..writeln(
      _code(_boxLeft + 22, 188, 'writeRow(2, ...)  <- now', fill: _blue),
    );

  // Stage 2: what is actually resident.
  b
    ..writeln(_box(238, 368, _blue))
    ..writeln(_boxTitle(262, 'in RAM', fill: _blue))
    ..writeln(
      '  <rect x="${_boxLeft + 30}" y="280" width="280" height="70" rx="6" '
      'fill="$_blueFill" stroke="$_blue" stroke-width="1.6"/>',
    )
    ..writeln(
      _text(
        (_boxLeft + _boxRight) / 2,
        304,
        'active row buffer: row 2 only',
        size: 14,
        weight: 'bold',
        fill: _blue,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _code(
        (_boxLeft + _boxRight) / 2,
        330,
        '[A3] [B3] [C3]',
        fill: _blue,
        anchor: 'middle',
        size: 15,
      ),
    );

  // Stage 3: the part that is already XML.
  b
    ..writeln(_box(400, 520, _green))
    ..writeln(_boxTitle(424, 'temp file on disk', fill: _green))
    ..writeln(_code(_boxLeft + 30, 452, '<row r="1">...</row>', fill: _muted))
    ..writeln(_code(_boxLeft + 30, 474, '<row r="2">...</row>', fill: _muted))
    ..writeln(
      _text(
        _boxLeft + 30,
        496,
        '(rows 0 and 1: flushed, cells freed)',
        size: 12,
        fill: _green,
      ),
    );

  // Stage 4: the file the caller asked for.
  b
    ..writeln(_box(552, 610, _orange, fill: _orangeFill))
    ..writeln(
      _text(
        (_boxLeft + _boxRight) / 2,
        577,
        'report.xlsx',
        size: 16,
        weight: 'bold',
        fill: _orange,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        (_boxLeft + _boxRight) / 2,
        598,
        'a ZIP of those XML parts',
        size: 13,
        fill: _orange,
        anchor: 'middle',
      ),
    );

  // Forward arrows down the spine, each labelled with what triggers it.
  const spine = (_boxLeft + _boxRight) / 2;
  b
    ..writeln(_arrowDown(spine, 206, 238))
    ..writeln(_code(spine + 14, 227, 'writeRow', fill: _muted, size: 12))
    ..writeln(_arrowDown(spine, 368, 400))
    ..writeln(
      _text(
        spine + 14,
        389,
        'on row change: flush, then free the cells',
        size: 12,
        fill: _muted,
      ),
    )
    ..writeln(_arrowDown(spine, 520, 552))
    ..writeln(_code(spine + 14, 541, 'close()', fill: _muted, size: 12));

  // The return path, which is the whole trade-off: it does not exist.
  b
    ..writeln(
      '  <path d="M $_boxLeft 460 L $_returnX 460 L $_returnX 150 '
      'L ${_boxLeft - 4} 150" fill="none" stroke="$_red" stroke-width="2" '
      'stroke-dasharray="6 5" marker-end="url(#headRed)"/>',
    )
    ..writeln(
      '  <line x1="${_returnX - 9}" y1="296" x2="${_returnX + 9}" y2="314" '
      'stroke="$_red" stroke-width="3.4" stroke-linecap="round"/>',
    )
    ..writeln(
      '  <line x1="${_returnX - 9}" y1="314" x2="${_returnX + 9}" y2="296" '
      'stroke="$_red" stroke-width="3.4" stroke-linecap="round"/>',
    );

  // The annotation column: one note per stage, aligned to its box.
  b
    ..writeln(
      _note(122, [
        'Write top to bottom. Column',
        'order within the row',
        'you are on is free.',
      ]),
    )
    ..writeln(
      _note(280, [
        'Default mode keeps every',
        'row here instead: a 1M',
        'by 10 sheet is 10M live',
        'cell objects, 1243.6 MiB.',
      ]),
    )
    ..writeln(
      _note(444, [
        'Finished worksheet XML,',
        'append-only. Nothing',
        'here is read back until',
        'close() copies it.',
      ]),
    )
    ..writeln(_note(572, ['Deflated into the zip', 'with the other parts.']));

  b
    ..writeln(
      _text(
        _width / 2,
        644,
        'The dashed arrow is the one call that is gone: writing a cell back on '
        'a flushed row throws XlsxWriterException.',
        size: 13,
        fill: _red,
        anchor: 'middle',
      ),
    )
    ..writeln('</svg>');
  return b.toString();
}

String _arrowMarker(String id, String color) =>
    '    <marker id="$id" viewBox="0 0 10 10" refX="9" refY="5" '
    'markerWidth="6" markerHeight="6" orient="auto-start-reverse">'
    '<path d="M 0 0 L 10 5 L 0 10 z" fill="$color"/></marker>';

String _box(double top, double bottom, String stroke, {String fill = 'none'}) =>
    '  <rect x="$_boxLeft" y="$top" width="${_boxRight - _boxLeft}" '
    'height="${bottom - top}" rx="8" fill="$fill" stroke="$stroke" '
    'stroke-width="2"/>';

String _boxTitle(double y, String label, {String fill = _ink}) => _text(
  (_boxLeft + _boxRight) / 2,
  y,
  label,
  size: 15,
  weight: 'bold',
  fill: fill,
  anchor: 'middle',
);

String _arrowDown(double x, double from, double to) =>
    '  <line x1="$x" y1="$from" x2="$x" y2="${to - 4}" stroke="$_line" '
    'stroke-width="2" marker-end="url(#head)"/>';

String _note(double firstBaseline, List<String> lines) {
  final b = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    b.writeln(
      _text(
        _noteLeft,
        firstBaseline + i * 18,
        lines[i],
        size: 13,
        fill: _muted,
      ),
    );
  }
  return b.toString().trimRight();
}

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

String _kib(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KiB';

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

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
