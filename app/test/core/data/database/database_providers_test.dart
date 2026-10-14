import 'dart:io';

import 'package:board_game_collector/core/data/database/database_providers.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/data/database/open_app_database.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../helpers/test_database.dart';

String _join(String a, String b, [String? c]) =>
    [a, b, ?c].join(Platform.pathSeparator);

/// Answers path_provider calls with folders inside a test directory.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async =>
      _join(root.path, 'support');

  @override
  Future<String?> getTemporaryPath() async => _join(root.path, 'tmp');
}

void main() {
  late Directory root;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('t027_');
    await Directory(_join(root.path, 'support')).create();
    await Directory(_join(root.path, 'tmp')).create();
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(root);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await root.delete(recursive: true);
  });

  File databaseFile() =>
      File(_join(root.path, 'support', '$appDatabaseName.sqlite'));

  test('openAppDatabase creates the file in the app support directory '
      'and keeps data across opens (AC1, AC5)', () async {
    final first = openAppDatabase();
    expect(databaseFile().existsSync(), isFalse, reason: 'opened lazily');
    final store = LocalGameStore(first);
    expect(
      (await store.saveConfirmedMatch(
        gtin13: '0036000291452',
        bggId: 13,
        confirmedAt: DateTime.utc(2026, 10, 13),
      )).isOk,
      isTrue,
    );
    await first.close();
    expect(databaseFile().existsSync(), isTrue);

    final second = openAppDatabase();
    final match = await LocalGameStore(second)
        .readConfirmedMatch('0036000291452');
    expect(match.valueOrNull?.bggId, 13);
    final version = await second.customSelect('PRAGMA user_version').get();
    expect(version.single.data.values.single, 1);
    await second.close();
  });

  test('appDatabaseProvider opens the app database and closes it on '
      'dispose', () async {
    final container = ProviderContainer();
    final db = container.read(appDatabaseProvider);
    await db.customSelect('SELECT 1').get();
    expect(databaseFile().existsSync(), isTrue);

    container.dispose();
    // The background isolate is gone: queries fail, and the store turns
    // that error into a Failure (AC6).
    final result = await LocalGameStore(db).readDetails(13);
    expect(result.failureOrNull, const StorageFailure());
  });

  test('localGameStoreProvider uses the app database', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final store = container.read(localGameStoreProvider);
    expect(store.maxCachedDetails, LocalGameStore.defaultMaxCachedDetails);
    final saved = await store.saveDetails(
      bggId: 13,
      detailsJson: '{}',
      fetchedAt: DateTime.utc(2026, 10, 13),
    );
    expect(saved, isA<Ok<void>>());
    expect(await db.select(db.games).get(), hasLength(1));
    // Debug test runs log failures through debugPrint.
    expect(store.log, isNotNull);
  });
}
