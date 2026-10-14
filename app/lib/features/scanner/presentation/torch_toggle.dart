import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The TorchToggle component (docs/ux/components.md): a 48 dp icon toggle
/// on the camera preview.
///
/// Its label is the action (`scanner.torchOn` while the torch is off,
/// `scanner.torchOff` while it is on), shown as the tooltip and read by
/// screen readers with the switch state. The screen announces the new state
/// (`scanner.torchLabelOn` / `scanner.torchLabelOff`) after a tap.
class TorchToggle extends StatelessWidget {
  const TorchToggle({required this.isOn, required this.onPressed, super.key});

  /// Whether the torch is on.
  final bool isOn;

  /// Toggles the torch; null disables the toggle (while the camera starts).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isOn ? l10n.scannerTorchOff : l10n.scannerTorchOn;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      toggled: isOn,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          isSelected: isOn,
          // Opaque surface colors, so the icon reads on any camera image.
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.square(48)),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surface,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? colors.onSurface.withValues(alpha: 0.38)
                  : states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.onSurface,
            ),
          ),
          icon: const Icon(Icons.flashlight_off_outlined),
          selectedIcon: const Icon(Icons.flashlight_on),
        ),
      ),
    );
  }
}
