import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// Search destination (title search). Placeholder until T-032.
///
/// Lives in the scanner feature with the rest of the lookup flow (scan,
/// manual entry, title search, lookup result).
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).searchTitle)),
      body: const PlaceholderBody(),
    );
  }
}
