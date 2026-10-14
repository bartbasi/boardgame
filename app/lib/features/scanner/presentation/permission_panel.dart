import 'package:flutter/material.dart';

/// The PermissionPanel component (docs/ux/components.md): a card in the
/// viewfinder area with an icon, a title (a heading), a body, and at most
/// one primary action. Used for the requesting, denied, permanently
/// denied, restricted, and camera unavailable states.
///
/// It scrolls when the text does not fit (200% text), and it is a polite
/// live region, so a change of state is announced (scanner.md section 7).
class PermissionPanel extends StatelessWidget {
  const PermissionPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Decorative icon over the title.
  final IconData icon;

  /// The panel title.
  final String title;

  /// The explanation.
  final String body;

  /// The primary action's label, or null for no action.
  final String? actionLabel;

  /// The primary action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = actionLabel;
    return Semantics(
      liveRegion: true,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            icon,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          container: true,
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        if (label != null) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: FilledButton(
                              onPressed: onAction,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: Text(label, textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
