import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// The database file name, without the `.sqlite` extension drift_flutter
/// adds.
const String appDatabaseName = 'board_game_collector';

/// Opens the app's database file in the app's private support directory.
///
/// drift_flutter runs SQLite in a background isolate
/// (`NativeDatabase.createBackgroundConnection`), so queries never block the
/// UI isolate (T-027 AC5). The file is created on first use, not here.
///
/// [directory] and [tempDirectory] exist for tests; the app uses the
/// platform's application support and temporary directories. Android Auto
/// Backup and iCloud Backup settings are not changed here (PRD Q38 is open).
AppDatabase openAppDatabase({
  Future<Directory> Function() directory = getApplicationSupportDirectory,
  Future<String?> Function()? tempDirectory,
}) {
  return AppDatabase(
    driftDatabase(
      name: appDatabaseName,
      native: DriftNativeOptions(
        databaseDirectory: directory,
        tempDirectoryPath: tempDirectory,
      ),
    ),
  );
}
