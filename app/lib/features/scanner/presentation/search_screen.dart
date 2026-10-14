import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/open_once.dart';
import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// Search destination (title search). Placeholder until T-032; the app bar
/// action that opens manual barcode entry already works (T-031, search.md:
/// a trailing 48 dp icon button labelled `search.actionManual`).
///
/// Lives in the scanner feature with the rest of the lookup flow (scan,
/// manual entry, title search, lookup result).
class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.onManualEntry, super.key});

  /// Opens manual barcode entry. Returns the push future; a double tap
  /// opens one screen (T-031 R1-S2).
  final Future<void> Function() onManualEntry;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with OpenOnce {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
        actions: [
          IconButton(
            onPressed: () => unawaited(openOnce(widget.onManualEntry)),
            tooltip: l10n.searchActionManual,
            icon: const Icon(Icons.dialpad),
          ),
        ],
      ),
      body: const PlaceholderBody(),
    );
  }
}
