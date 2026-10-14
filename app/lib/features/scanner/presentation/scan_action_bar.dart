import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The ScanActionBar component (docs/ux/components.md): "Enter barcode" and
/// "Search by title", visible in every scanner state (scanner.md section 1).
///
/// [stacked] puts the buttons in a full-width column (phone landscape, and
/// large text). Otherwise they sit side by side with equal width, each at
/// most [maxButtonWidth] wide, and switch to a column by themselves when a
/// label would wrap past 2 lines (scanner.md section 2, 200% text).
class ScanActionBar extends StatelessWidget {
  const ScanActionBar({
    required this.onManualEntry,
    required this.onSearch,
    this.stacked = false,
    this.maxButtonWidth = double.infinity,
    super.key,
  });

  /// Opens manual entry.
  final VoidCallback onManualEntry;

  /// Switches to Search.
  final VoidCallback onSearch;

  /// Always stack the buttons.
  final bool stacked;

  /// Width cap of each button in a row (280 dp on medium and expanded).
  final double maxButtonWidth;

  static const double _gap = 12;

  /// Space a FilledButton.icon takes besides its label: 16 dp start and
  /// 24 dp end padding, an 18 dp icon, and an 8 dp gap.
  static const double _buttonChrome = 16 + 24 + 18 + 8;

  /// Whether both labels fit in at most 2 lines on a button [width] wide.
  static bool labelsFit(
    BuildContext context,
    double width,
    List<String> labels,
  ) {
    final style = Theme.of(context).textTheme.labelLarge;
    final textScaler = MediaQuery.textScalerOf(context);
    final textWidth = width - _buttonChrome;
    if (textWidth <= 0) return false;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout(maxWidth: textWidth);
      final lines = painter.computeLineMetrics().length;
      painter.dispose();
      if (lines > 2) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.scannerActionManual, l10n.scannerActionSearch];
    final manual = FilledButton.tonalIcon(
      onPressed: onManualEntry,
      style: _style,
      icon: const Icon(Icons.dialpad),
      label: Text(labels[0], textAlign: TextAlign.center),
    );
    final search = FilledButton.tonalIcon(
      onPressed: onSearch,
      style: _style,
      icon: const Icon(Icons.search),
      label: Text(labels[1], textAlign: TextAlign.center),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 2 * maxButtonWidth + _gap;
        final buttonWidth = ((rowWidth - _gap) / 2).clamp(0.0, maxButtonWidth);
        if (stacked || !labelsFit(context, buttonWidth, labels)) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxButtonWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  manual,
                  const SizedBox(height: _gap),
                  search,
                ],
              ),
            ),
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: buttonWidth, child: manual),
            const SizedBox(width: _gap),
            SizedBox(width: buttonWidth, child: search),
          ],
        );
      },
    );
  }

  static final ButtonStyle _style = FilledButton.styleFrom(
    minimumSize: const Size(48, 48),
  );
}
