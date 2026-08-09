// Generates doc/benchmark.svg and doc/benchmark.png, the chart in the README.
//
//   dart run tool/benchmark_chart.dart
//
// The SVG is written unconditionally. The PNG is rasterized with
// `rsvg-convert` if it is on PATH (`brew install librsvg`); otherwise the
// command to run is printed and the SVG is left for you to convert. A second
// optional pass quantizes the PNG with ImageMagick, which cuts the file to
// roughly a third on flat-colour artwork like this; without it the PNG is
// still correct, just larger.
//
// The canvas is deliberately close to square. pub.dev renders a `screenshots:`
// entry as a 190x190 thumbnail and fits rather than crops, so a wide chart
// arrives on the package card as a thin unreadable strip.
//
// The numbers below are not computed here. They are transcribed from runs of
// `bench/bench.dart`, so the chart cannot drift away from the benchmark by
// accident: to change the chart you have to re-run the benchmark and paste new
// figures, which is the same edit a reviewer would ask for anyway. Each series
// records the command that produced it and the median of the runs.
import 'dart:io';

/// Peak RSS minus the baseline sampled before the first write: the part of the
/// process peak the export is responsible for. This is what the chart plots.
///
/// Measured on Apple Silicon, macOS 26.3, Dart 3.11.0, with
/// `dart run bench/bench.dart <rows> 10`: five runs at 100k, three at 10k and
/// 1M, per-column medians. Raw peak and baseline are carried along because the
/// whole point of the chart is that the difference between them is where the
/// story is.
const _measurements = [
  _Point(rows: 10000, constantMemory: 0.1, defaultMode: 12.5),
  _Point(rows: 100000, constantMemory: 0.2, defaultMode: 124.3),
  _Point(rows: 1000000, constantMemory: 0.3, defaultMode: 1243.6),
];

/// The pure-Dart `excel` package on the same workload, same baseline
/// discipline, same machine and day: 100,000 rows by 10 columns, peak 1927 MiB
/// against a 263 MiB baseline, three runs. Measured in a throwaway package
/// because `excel` and this package's dev dependency `archive` need
/// incompatible major versions of `archive`, so they cannot share one pubspec.
const _excelRows = 100000;
const _excelAttributable = 1664.5;

/// Baselines the two harnesses sat at before their first write, quoted in the
/// footnote so the reader can reconstruct the raw peaks. They differ because
/// they are different processes: `excel` pulls in `archive` and its own object
/// model, and starts 75 MiB higher than this package does.
const _xlsxwriterBaseline = 188;
const _excelBaseline = 263;

const _title = 'What the export itself costs';
const _subtitle =
    'peak RSS minus the same counter sampled before the first write';

// Canvas. Rendered at 2x, so the PNG lands at 1400x1300: near enough to square
// that pub.dev's 190x190 thumbnail stays legible.
const _width = 700.0;
const _height = 650.0;
const _scale = 2;

/// A rasterized chart this size lands around 170 KB straight out of
/// `rsvg-convert` and around 45 KB once quantized. Anything much past this is
/// a sign the artwork picked up a gradient or a photo.
const _pngBudgetBytes = 80 * 1024;

// Plot area.
const _plotLeft = 108.0;
const _plotRight = 662.0;
const _plotTop = 152.0;
const _plotBottom = 520.0;
const _yMax = 1800.0;
const _yTickStep = 300.0;

// Palette, matched to doc/banner.svg's siblings: warm paper, one blue, one
// orange, one red.
const _paper = '#FAF6F0';
const _ink = '#1A1A1A';
const _muted = '#6B6B6B';
const _grid = '#E4DCD0';
const _axis = '#B9AE9E';
const _blue = '#1F77B4';
const _orange = '#E4610F';
const _red = '#C62828';

const _serif = "Georgia, 'Times New Roman', Times, serif";

void main() {
  if (!Directory('doc').existsSync()) {
    stderr.writeln(
      'run this from the package root: doc/ not found in '
      '${Directory.current.path}',
    );
    exit(1);
  }

  final svgFile = File('doc/benchmark.svg')..writeAsStringSync(_buildSvg());
  stdout.writeln('wrote ${svgFile.path}');

  const png = 'doc/benchmark.png';
  final rsvg = _which('rsvg-convert');
  if (rsvg == null) {
    stdout.writeln(
      'rsvg-convert not found; install it (brew install librsvg) or run:\n'
      '  rsvg-convert -z $_scale doc/benchmark.svg -o $png',
    );
    return;
  }
  _run(rsvg, ['-z', '$_scale', 'doc/benchmark.svg', '-o', png]);
  var bytes = File(png).lengthSync();
  stdout.writeln(
    'wrote $png (${_width.round() * _scale}x${_height.round() * _scale}, '
    '${_kib(bytes)})',
  );

  // Every colour in this chart is flat, so a palette costs nothing visible and
  // saves about two thirds of the file. Keep the result only if it is smaller.
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
    ..writeln('  <rect width="$_width" height="$_height" fill="$_paper"/>')
    ..writeln(
      _text(_width / 2, 58, _title, size: 28, weight: 'bold', anchor: 'middle'),
    )
    ..writeln(
      _text(
        _width / 2,
        86,
        _subtitle,
        size: 15,
        fill: _muted,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        108,
        'N rows by 10 columns, each engine in its own process',
        size: 15,
        fill: _muted,
        anchor: 'middle',
      ),
    );

  // Horizontal gridlines and y labels.
  for (var v = 0.0; v <= _yMax; v += _yTickStep) {
    final y = _y(v);
    b
      ..writeln(
        '  <line x1="$_plotLeft" y1="${_f(y)}" x2="$_plotRight" y2="${_f(y)}" '
        'stroke="${v == 0 ? _axis : _grid}" stroke-width="${v == 0 ? 1.4 : 1}"/>',
      )
      ..writeln(
        _text(
          _plotLeft - 14,
          y + 5,
          _int(v),
          size: 14,
          fill: _muted,
          anchor: 'end',
        ),
      );
  }
  b.writeln(
    _text(
      26,
      (_plotTop + _plotBottom) / 2,
      'MiB the export added to peak RSS',
      size: 14,
      fill: _muted,
      anchor: 'middle',
      transform: 'rotate(-90 26 ${_f((_plotTop + _plotBottom) / 2)})',
    ),
  );

  // X ticks: three decades, evenly spaced (a log axis).
  const labels = ['10k', '100k', '1M'];
  for (var i = 0; i < _measurements.length; i++) {
    final x = _x(i);
    b
      ..writeln(
        '  <line x1="${_f(x)}" y1="$_plotBottom" x2="${_f(x)}" '
        'y2="${_f(_plotBottom + 7)}" stroke="$_axis" stroke-width="1.4"/>',
      )
      ..writeln(
        _text(x, _plotBottom + 30, labels[i], size: 16, anchor: 'middle'),
      );
  }
  b.writeln(
    _text(
      (_plotLeft + _plotRight) / 2,
      _plotBottom + 58,
      'rows written (log scale)',
      size: 14,
      fill: _muted,
      anchor: 'middle',
    ),
  );

  // The excel reference point, drawn before the lines so the lines win any
  // overlap.
  final excelX = _x(_measurements.indexWhere((p) => p.rows == _excelRows));
  final excelY = _y(_excelAttributable);
  b
    ..writeln(
      '  <circle cx="${_f(excelX)}" cy="${_f(excelY)}" r="7" fill="$_red"/>',
    )
    ..writeln(
      _text(
        excelX + 16,
        excelY - 6,
        'excel 4.0.6 (pure Dart)',
        size: 15,
        weight: 'bold',
        fill: _red,
      ),
    )
    ..writeln(
      _text(
        excelX + 16,
        excelY + 14,
        '$_excelAttributable MiB at 100k rows',
        size: 14,
        fill: _red,
      ),
    );

  // Default mode: climbs by a factor of ten for every factor of ten in rows.
  b.writeln(_polyline((p) => p.defaultMode, _orange));
  // Constant memory: sits on the zero line at every size.
  b.writeln(_polyline((p) => p.constantMemory, _blue));

  for (var i = 0; i < _measurements.length; i++) {
    b
      ..writeln(_dot(_x(i), _y(_measurements[i].defaultMode), _orange))
      ..writeln(_dot(_x(i), _y(_measurements[i].constantMemory), _blue));
  }

  // End labels sit above their series and are right-anchored inside the plot,
  // which keeps a square canvas from needing a gutter it cannot spare.
  final last = _measurements.last;
  b
    ..writeln(
      _text(
        _plotRight - 7,
        _y(last.defaultMode) - 30,
        'default (in memory)',
        size: 15,
        weight: 'bold',
        fill: _orange,
        anchor: 'end',
      ),
    )
    ..writeln(
      _text(
        _plotRight - 7,
        _y(last.defaultMode) - 10,
        '${last.defaultMode} MiB at 1M rows',
        size: 14,
        fill: _orange,
        anchor: 'end',
      ),
    )
    ..writeln(
      _text(
        _plotRight - 7,
        _y(0) - 34,
        'constant memory',
        size: 15,
        weight: 'bold',
        fill: _blue,
        anchor: 'end',
      ),
    )
    ..writeln(
      _text(
        _plotRight - 7,
        _y(0) - 14,
        '0.1 to 0.3 MiB, at every size',
        size: 14,
        fill: _blue,
        anchor: 'end',
      ),
    )
    // Placed in the empty upper-left quadrant rather than beside the blue
    // line: down there it would sit underneath the orange one.
    ..writeln(
      _text(
        _plotLeft + 12,
        262,
        'The blue line is the axis.',
        size: 18,
        weight: 'bold',
        fill: _blue,
      ),
    )
    ..writeln(
      _text(
        _plotLeft + 12,
        288,
        'Streaming never raised the process peak,',
        size: 15,
        fill: _blue,
      ),
    )
    ..writeln(
      _text(
        _plotLeft + 12,
        308,
        'at any of the three sizes.',
        size: 15,
        fill: _blue,
      ),
    );

  b
    ..writeln(
      _text(
        _width / 2,
        _height - 42,
        'Apple Silicon, Dart 3.11. Baseline before the first write: '
        '$_xlsxwriterBaseline MiB for xlsxwriter, $_excelBaseline MiB for '
        'excel;',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        _height - 24,
        'add it back to get raw peak RSS. The excel figure comes from a '
        'separate harness; the README says why.',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    )
    ..writeln(
      _text(
        _width / 2,
        _height - 6,
        'Reproduce the two xlsxwriter modes with: '
        'dart run bench/bench.dart 1000000 10',
        size: 13,
        fill: _muted,
        anchor: 'middle',
      ),
    )
    ..writeln('</svg>');
  return b.toString();
}

String _polyline(double Function(_Point) pick, String color) {
  final points = [
    for (var i = 0; i < _measurements.length; i++)
      '${_f(_x(i))},${_f(_y(pick(_measurements[i])))}',
  ].join(' ');
  return '  <polyline points="$points" fill="none" stroke="$color" '
      'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>';
}

String _dot(double x, double y, String color) =>
    '  <circle cx="${_f(x)}" cy="${_f(y)}" r="6" fill="$color"/>';

String _text(
  double x,
  double y,
  String value, {
  required double size,
  String fill = _ink,
  String weight = 'normal',
  String anchor = 'start',
  String? transform,
}) {
  final t = transform == null ? '' : ' transform="$transform"';
  return '  <text x="${_f(x)}" y="${_f(y)}" font-family="$_serif" '
      'font-size="$size" font-weight="$weight" fill="$fill" '
      'text-anchor="$anchor"$t>${_escape(value)}</text>';
}

/// Three decades across the plot, evenly spaced.
double _x(int index) =>
    _plotLeft + (_plotRight - _plotLeft) * index / (_measurements.length - 1);

double _y(double mib) => _plotBottom - (_plotBottom - _plotTop) * (mib / _yMax);

String _f(double v) => v.toStringAsFixed(1);

String _int(double v) => v.round().toString();

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

class _Point {
  const _Point({
    required this.rows,
    required this.constantMemory,
    required this.defaultMode,
  });

  final int rows;
  final double constantMemory;
  final double defaultMode;
}
