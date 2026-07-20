/// Horizontal cell alignment, applied with [Format.align].
///
/// Values mirror libxlsxwriter's `lxw_format_alignments` horizontal members.
enum Alignment {
  /// Excel's default alignment for the cell's data type.
  none(0),

  /// Left aligned.
  left(1),

  /// Centered.
  center(2),

  /// Right aligned.
  right(3),

  /// Fill: repeat the cell value to fill the width.
  fill(4),

  /// Justified.
  justify(5),

  /// Centered across the selection.
  centerAcross(6),

  /// Distributed.
  distributed(7);

  const Alignment(this.value);

  /// The libxlsxwriter enum value passed across the FFI boundary.
  final int value;
}

/// Vertical cell alignment, applied with [Format.verticalAlign].
///
/// Values mirror libxlsxwriter's `lxw_format_alignments` vertical members.
enum VerticalAlignment {
  /// Top aligned.
  top(8),

  /// Bottom aligned (Excel's default).
  bottom(9),

  /// Vertically centered.
  center(10),

  /// Vertically justified.
  justify(11),

  /// Vertically distributed.
  distributed(12);

  const VerticalAlignment(this.value);

  /// The libxlsxwriter enum value passed across the FFI boundary.
  final int value;
}

/// Underline style, applied with [Format.underline].
///
/// Values mirror libxlsxwriter's `lxw_format_underlines`.
enum Underline {
  /// No underline.
  none(0),

  /// Single underline.
  single(1),

  /// Double underline.
  double(2),

  /// Single accounting underline.
  singleAccounting(3),

  /// Double accounting underline.
  doubleAccounting(4);

  const Underline(this.value);

  /// The libxlsxwriter enum value passed across the FFI boundary.
  final int value;
}

/// Cell border style, applied with [Format.border].
///
/// Values mirror libxlsxwriter's `lxw_format_borders`.
enum Border {
  /// No border.
  none(0),

  /// Thin border.
  thin(1),

  /// Medium border.
  medium(2),

  /// Dashed border.
  dashed(3),

  /// Dotted border.
  dotted(4),

  /// Thick border.
  thick(5),

  /// Double line border.
  double(6),

  /// Hairline border.
  hair(7),

  /// Medium dashed border.
  mediumDashed(8),

  /// Dash-dot border.
  dashDot(9),

  /// Medium dash-dot border.
  mediumDashDot(10),

  /// Dash-dot-dot border.
  dashDotDot(11),

  /// Medium dash-dot-dot border.
  mediumDashDotDot(12),

  /// Slant dash-dot border.
  slantDashDot(13);

  const Border(this.value);

  /// The libxlsxwriter enum value passed across the FFI boundary.
  final int value;
}

/// The kind of chart created with [Workbook.addChart].
///
/// Values are the shim's own stable codes; the native shim maps each to the
/// matching libxlsxwriter `LXW_CHART_*` type, so this enum never depends on
/// libxlsxwriter's internal enum values.
enum ChartType {
  /// Vertical bars (a column chart).
  column(0),

  /// Horizontal bars.
  bar(1),

  /// A line chart.
  line(2),

  /// A filled area chart.
  area(3),

  /// A pie chart. Uses only the first series.
  pie(4),

  /// A doughnut chart. Uses only the first series.
  doughnut(5),

  /// An X/Y scatter chart.
  scatter(6),

  /// A radar chart.
  radar(7);

  const ChartType(this.value);

  /// The shim chart-type code passed across the FFI boundary.
  final int value;
}
