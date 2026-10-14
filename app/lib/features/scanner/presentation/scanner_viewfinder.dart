import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../l10n/app_localizations.dart';

/// The ScannerViewfinder component (docs/ux/components.md): the camera
/// preview with a scrim, the scan frame, an optional hint pill, and the
/// torch toggle on top (scanner.md sections 2 and 7).
///
/// The frame is a rounded rectangle at 2.5:1, 70% of the preview's shorter
/// side, centered slightly above the middle. When [detected], the frame
/// turns primary with a light primary fill (no fill with reduce motion)
/// and a check shows in its middle.
///
/// While [starting], the area shows surfaceContainerHighest with a small
/// progress indicator and `scanner.starting` over the preview (which the
/// camera plugin needs in the tree before it starts), and no frame or hint.
class ScannerViewfinder extends StatelessWidget {
  const ScannerViewfinder({
    required this.preview,
    this.starting = false,
    this.detected = false,
    this.hint,
    this.torchToggle,
    super.key,
  });

  /// The live camera preview, or null before the camera starts.
  final Widget? preview;

  /// Whether the camera is starting.
  final bool starting;

  /// Whether the success feedback shows.
  final bool detected;

  /// The hint on its pill, or null when the layout shows it elsewhere
  /// (phone landscape).
  final String? hint;

  /// The torch toggle, or null when the device has no torch.
  final Widget? torchToggle;

  /// Frame width over the preview's shorter side.
  static const double frameShare = 0.7;

  /// Frame width over frame height.
  static const double frameAspect = 2.5;

  /// The frame's rectangle in a preview of [size].
  static Rect frameRect(Size size) {
    final width = math.min(size.width, size.height) * frameShare;
    final height = width / frameAspect;
    final center = Offset(size.width / 2, size.height * 0.45);
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final hint = this.hint;
    final torch = torchToggle;
    final preview = this.preview;
    return Semantics(
      explicitChildNodes: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (preview != null)
            Semantics(
              sortKey: const OrdinalSortKey(1),
              label: starting ? null : l10n.scannerViewfinderLabel,
              container: true,
              child: ExcludeSemantics(child: preview),
            ),
          if (starting)
            Semantics(
              sortKey: const OrdinalSortKey(1),
              container: true,
              child: ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.scannerStarting,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final frame = frameRect(constraints.biggest);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FramePainter(
                            scrim: colors.scrim.withValues(alpha: 0.55),
                            // White on the scrim in both themes
                            // (scanner.md section 7).
                            frameColor: detected
                                ? colors.primary
                                : Colors.white,
                            fill: detected && !reduceMotion
                                ? colors.primary.withValues(alpha: 0.3)
                                : null,
                          ),
                        ),
                      ),
                      if (detected)
                        Positioned.fromRect(
                          rect: frame,
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.check,
                                  size: 32,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (hint != null && !starting)
            Positioned(
              top: 24,
              // Leaves room for the torch toggle in the top-right corner.
              left: 72,
              right: 72,
              child: Semantics(
                sortKey: const OrdinalSortKey(2),
                container: true,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (torch != null)
            Positioned(
              top: 12,
              right: 12,
              child: Semantics(
                sortKey: const OrdinalSortKey(0),
                container: true,
                child: torch,
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints the scrim around the frame and the frame's outline.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.scrim, required this.frameColor, this.fill});

  final Color scrim;
  final Color frameColor;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      ScannerViewfinder.frameRect(size),
      const Radius.circular(16),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(outside, Paint()..color = scrim);
    final fill = this.fill;
    if (fill != null) canvas.drawRRect(frame, Paint()..color = fill);
    final stroke = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(frame, stroke..strokeWidth = 2);
    // The 4 corner marks: the outline drawn thick, clipped to the corners.
    final rect = frame.outerRect;
    const mark = 28.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight - const Offset(mark, 0),
      rect.bottomLeft - const Offset(0, mark),
      rect.bottomRight - const Offset(mark, mark),
    ]) {
      canvas
        ..save()
        ..clipRect((corner - const Offset(4, 4)) & const Size.square(mark + 8))
        ..drawRRect(frame, stroke..strokeWidth = 6)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.scrim != scrim || old.frameColor != frameColor || old.fill != fill;
}
