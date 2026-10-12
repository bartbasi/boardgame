import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Collection destination. Shows a placeholder list until T-039 so the shell
/// can prove that scroll position and back stacks are kept per destination.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({required this.onOpenItem, super.key});

  /// Number of rows in the placeholder list.
  static const int placeholderItemCount = 50;

  /// Opens the placeholder item screen for a row number (1 based).
  final ValueChanged<int> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.collectionTitle)),
      body: ListView.builder(
        key: const PageStorageKey<String>('collection-placeholder-list'),
        itemCount: placeholderItemCount,
        itemBuilder: (context, index) {
          final number = index + 1;
          return ListTile(
            title: Text(l10n.devPlaceholderItem(number)),
            onTap: () => onOpenItem(number),
          );
        },
      ),
    );
  }
}
