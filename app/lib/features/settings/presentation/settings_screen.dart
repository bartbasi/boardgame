import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_body.dart';
import '../../../l10n/app_localizations.dart';

/// Settings destination. Placeholder until the settings ticket.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: const PlaceholderBody(),
    );
  }
}
