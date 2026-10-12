/// Material window size classes by width
/// (docs/ux/screens/app-shell.md, section 2).
///
/// Compact is under 600 dp, medium is 600 to 839 dp, and expanded is 840 dp
/// and up. Phone landscape (844 dp wide) is expanded.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// Lower width bound of [medium], in dp.
  static const double mediumMinWidth = 600;

  /// Lower width bound of [expanded], in dp.
  static const double expandedMinWidth = 840;

  /// The size class for a window [width] in logical pixels (dp).
  static WindowSizeClass fromWidth(double width) {
    if (width < mediumMinWidth) return WindowSizeClass.compact;
    if (width < expandedMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }
}
