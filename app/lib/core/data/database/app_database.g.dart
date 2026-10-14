// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bggIdMeta = const VerificationMeta('bggId');
  @override
  late final GeneratedColumn<int> bggId = GeneratedColumn<int>(
    'bgg_id',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>('bgg_id > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> fetchedAt =
      GeneratedColumn<int>(
        'fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($GamesTable.$converterfetchedAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastViewedAt =
      GeneratedColumn<int>(
        'last_viewed_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($GamesTable.$converterlastViewedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bggId,
    detailsJson,
    fetchedAt,
    lastViewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bgg_id')) {
      context.handle(
        _bggIdMeta,
        bggId.isAcceptableOrUnknown(data['bgg_id']!, _bggIdMeta),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bggId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bgg_id'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      fetchedAt: $GamesTable.$converterfetchedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}fetched_at'],
        ),
      ),
      lastViewedAt: $GamesTable.$converterlastViewedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_viewed_at'],
        ),
      ),
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterfetchedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime?, int?> $converterfetchedAtn =
      NullAwareTypeConverter.wrap($converterfetchedAt);
  static TypeConverter<DateTime, int> $converterlastViewedAt =
      const EpochMillisConverter();
  static TypeConverter<DateTime?, int?> $converterlastViewedAtn =
      NullAwareTypeConverter.wrap($converterlastViewedAt);
}

class GameRow extends DataClass implements Insertable<GameRow> {
  /// Internal surrogate id. Never leaves the data layer.
  final int id;

  /// The BoardGameGeek id, unique when present.
  final int? bggId;

  /// The cached game details as the backend's JSON. Null when the game has
  /// no cached details, for example after eviction when a barcode match
  /// still points to the game.
  final String? detailsJson;

  /// When [detailsJson] was fetched from the backend.
  final DateTime? fetchedAt;

  /// When the user last opened the game. Eviction removes the details of the
  /// least recently viewed games first.
  final DateTime? lastViewedAt;
  const GameRow({
    required this.id,
    this.bggId,
    this.detailsJson,
    this.fetchedAt,
    this.lastViewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || bggId != null) {
      map['bgg_id'] = Variable<int>(bggId);
    }
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<int>(
        $GamesTable.$converterfetchedAtn.toSql(fetchedAt),
      );
    }
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<int>(
        $GamesTable.$converterlastViewedAtn.toSql(lastViewedAt),
      );
    }
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      bggId: bggId == null && nullToAbsent
          ? const Value.absent()
          : Value(bggId),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
    );
  }

  factory GameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<int>(json['id']),
      bggId: serializer.fromJson<int?>(json['bggId']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      fetchedAt: serializer.fromJson<DateTime?>(json['fetchedAt']),
      lastViewedAt: serializer.fromJson<DateTime?>(json['lastViewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bggId': serializer.toJson<int?>(bggId),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'fetchedAt': serializer.toJson<DateTime?>(fetchedAt),
      'lastViewedAt': serializer.toJson<DateTime?>(lastViewedAt),
    };
  }

  GameRow copyWith({
    int? id,
    Value<int?> bggId = const Value.absent(),
    Value<String?> detailsJson = const Value.absent(),
    Value<DateTime?> fetchedAt = const Value.absent(),
    Value<DateTime?> lastViewedAt = const Value.absent(),
  }) => GameRow(
    id: id ?? this.id,
    bggId: bggId.present ? bggId.value : this.bggId,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
    lastViewedAt: lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      bggId: data.bggId.present ? data.bggId.value : this.bggId,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('bggId: $bggId, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastViewedAt: $lastViewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bggId, detailsJson, fetchedAt, lastViewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.bggId == this.bggId &&
          other.detailsJson == this.detailsJson &&
          other.fetchedAt == this.fetchedAt &&
          other.lastViewedAt == this.lastViewedAt);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<int> id;
  final Value<int?> bggId;
  final Value<String?> detailsJson;
  final Value<DateTime?> fetchedAt;
  final Value<DateTime?> lastViewedAt;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.bggId = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    this.bggId = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
  });
  static Insertable<GameRow> custom({
    Expression<int>? id,
    Expression<int>? bggId,
    Expression<String>? detailsJson,
    Expression<int>? fetchedAt,
    Expression<int>? lastViewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bggId != null) 'bgg_id': bggId,
      if (detailsJson != null) 'details_json': detailsJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<int?>? bggId,
    Value<String?>? detailsJson,
    Value<DateTime?>? fetchedAt,
    Value<DateTime?>? lastViewedAt,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      bggId: bggId ?? this.bggId,
      detailsJson: detailsJson ?? this.detailsJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bggId.present) {
      map['bgg_id'] = Variable<int>(bggId.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(
        $GamesTable.$converterfetchedAtn.toSql(fetchedAt.value),
      );
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<int>(
        $GamesTable.$converterlastViewedAtn.toSql(lastViewedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('bggId: $bggId, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastViewedAt: $lastViewedAt')
          ..write(')'))
        .toString();
  }
}

class $BarcodeMatchesTable extends BarcodeMatches
    with TableInfo<$BarcodeMatchesTable, BarcodeMatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BarcodeMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gtin13Meta = const VerificationMeta('gtin13');
  @override
  late final GeneratedColumn<String> gtin13 = GeneratedColumn<String>(
    'gtin13',
    aliasedName,
    false,
    check: () =>
        gtin13.length.equals(13) &
        const CustomExpression<bool>("gtin13 NOT GLOB '*[^0-9]*'"),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> confirmedAt =
      GeneratedColumn<int>(
        'confirmed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($BarcodeMatchesTable.$converterconfirmedAt);
  @override
  List<GeneratedColumn> get $columns => [gtin13, gameId, confirmedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'barcode_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<BarcodeMatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gtin13')) {
      context.handle(
        _gtin13Meta,
        gtin13.isAcceptableOrUnknown(data['gtin13']!, _gtin13Meta),
      );
    } else if (isInserting) {
      context.missing(_gtin13Meta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gtin13};
  @override
  BarcodeMatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BarcodeMatchRow(
      gtin13: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gtin13'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      confirmedAt: $BarcodeMatchesTable.$converterconfirmedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}confirmed_at'],
        )!,
      ),
    );
  }

  @override
  $BarcodeMatchesTable createAlias(String alias) {
    return $BarcodeMatchesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterconfirmedAt =
      const EpochMillisConverter();
}

class BarcodeMatchRow extends DataClass implements Insertable<BarcodeMatchRow> {
  /// 13 ASCII digits.
  final String gtin13;

  /// The matched game's internal id.
  final int gameId;

  /// When the match was confirmed.
  final DateTime confirmedAt;
  const BarcodeMatchRow({
    required this.gtin13,
    required this.gameId,
    required this.confirmedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gtin13'] = Variable<String>(gtin13);
    map['game_id'] = Variable<int>(gameId);
    {
      map['confirmed_at'] = Variable<int>(
        $BarcodeMatchesTable.$converterconfirmedAt.toSql(confirmedAt),
      );
    }
    return map;
  }

  BarcodeMatchesCompanion toCompanion(bool nullToAbsent) {
    return BarcodeMatchesCompanion(
      gtin13: Value(gtin13),
      gameId: Value(gameId),
      confirmedAt: Value(confirmedAt),
    );
  }

  factory BarcodeMatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BarcodeMatchRow(
      gtin13: serializer.fromJson<String>(json['gtin13']),
      gameId: serializer.fromJson<int>(json['gameId']),
      confirmedAt: serializer.fromJson<DateTime>(json['confirmedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gtin13': serializer.toJson<String>(gtin13),
      'gameId': serializer.toJson<int>(gameId),
      'confirmedAt': serializer.toJson<DateTime>(confirmedAt),
    };
  }

  BarcodeMatchRow copyWith({
    String? gtin13,
    int? gameId,
    DateTime? confirmedAt,
  }) => BarcodeMatchRow(
    gtin13: gtin13 ?? this.gtin13,
    gameId: gameId ?? this.gameId,
    confirmedAt: confirmedAt ?? this.confirmedAt,
  );
  BarcodeMatchRow copyWithCompanion(BarcodeMatchesCompanion data) {
    return BarcodeMatchRow(
      gtin13: data.gtin13.present ? data.gtin13.value : this.gtin13,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      confirmedAt: data.confirmedAt.present
          ? data.confirmedAt.value
          : this.confirmedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeMatchRow(')
          ..write('gtin13: $gtin13, ')
          ..write('gameId: $gameId, ')
          ..write('confirmedAt: $confirmedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gtin13, gameId, confirmedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeMatchRow &&
          other.gtin13 == this.gtin13 &&
          other.gameId == this.gameId &&
          other.confirmedAt == this.confirmedAt);
}

class BarcodeMatchesCompanion extends UpdateCompanion<BarcodeMatchRow> {
  final Value<String> gtin13;
  final Value<int> gameId;
  final Value<DateTime> confirmedAt;
  final Value<int> rowid;
  const BarcodeMatchesCompanion({
    this.gtin13 = const Value.absent(),
    this.gameId = const Value.absent(),
    this.confirmedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BarcodeMatchesCompanion.insert({
    required String gtin13,
    required int gameId,
    required DateTime confirmedAt,
    this.rowid = const Value.absent(),
  }) : gtin13 = Value(gtin13),
       gameId = Value(gameId),
       confirmedAt = Value(confirmedAt);
  static Insertable<BarcodeMatchRow> custom({
    Expression<String>? gtin13,
    Expression<int>? gameId,
    Expression<int>? confirmedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gtin13 != null) 'gtin13': gtin13,
      if (gameId != null) 'game_id': gameId,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BarcodeMatchesCompanion copyWith({
    Value<String>? gtin13,
    Value<int>? gameId,
    Value<DateTime>? confirmedAt,
    Value<int>? rowid,
  }) {
    return BarcodeMatchesCompanion(
      gtin13: gtin13 ?? this.gtin13,
      gameId: gameId ?? this.gameId,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gtin13.present) {
      map['gtin13'] = Variable<String>(gtin13.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<int>(
        $BarcodeMatchesTable.$converterconfirmedAt.toSql(confirmedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BarcodeMatchesCompanion(')
          ..write('gtin13: $gtin13, ')
          ..write('gameId: $gameId, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GamesTable games = $GamesTable(this);
  late final $BarcodeMatchesTable barcodeMatches = $BarcodeMatchesTable(this);
  late final Index barcodeMatchesGameId = Index(
    'barcode_matches_game_id',
    'CREATE INDEX barcode_matches_game_id ON barcode_matches (game_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    games,
    barcodeMatches,
    barcodeMatchesGameId,
  ];
}

typedef $$GamesTableCreateCompanionBuilder = GamesCompanion Function({
  Value<int> id,
  Value<int?> bggId,
  Value<String?> detailsJson,
  Value<DateTime?> fetchedAt,
  Value<DateTime?> lastViewedAt,
});
typedef $$GamesTableUpdateCompanionBuilder = GamesCompanion Function({
  Value<int> id,
  Value<int?> bggId,
  Value<String?> detailsJson,
  Value<DateTime?> fetchedAt,
  Value<DateTime?> lastViewedAt,
});

final class $$GamesTableReferences
    extends BaseReferences<_$AppDatabase, $GamesTable, GameRow> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BarcodeMatchesTable, List<BarcodeMatchRow>>
  _barcodeMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.barcodeMatches,
    aliasName: 'games__id__barcode_matches__game_id',
  );

  $$BarcodeMatchesTableProcessedTableManager get barcodeMatchesRefs {
    final manager = $$BarcodeMatchesTableTableManager(
      $_db,
      $_db.barcodeMatches,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_barcodeMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bggId => $composableBuilder(
    column: $table.bggId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get fetchedAt =>
      $composableBuilder(
        column: $table.fetchedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastViewedAt =>
      $composableBuilder(
        column: $table.lastViewedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> barcodeMatchesRefs(
    Expression<bool> Function($$BarcodeMatchesTableFilterComposer f) f,
  ) {
    final $$BarcodeMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.barcodeMatches,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BarcodeMatchesTableFilterComposer(
            $db: $db,
            $table: $db.barcodeMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bggId => $composableBuilder(
    column: $table.bggId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bggId =>
      $composableBuilder(column: $table.bggId, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastViewedAt =>
      $composableBuilder(
        column: $table.lastViewedAt,
        builder: (column) => column,
      );

  Expression<T> barcodeMatchesRefs<T extends Object>(
    Expression<T> Function($$BarcodeMatchesTableAnnotationComposer a) f,
  ) {
    final $$BarcodeMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.barcodeMatches,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BarcodeMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.barcodeMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, $$GamesTableReferences),
          GameRow,
          PrefetchHooks Function({bool barcodeMatchesRefs})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> bggId = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                bggId: bggId,
                detailsJson: detailsJson,
                fetchedAt: fetchedAt,
                lastViewedAt: lastViewedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> bggId = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                bggId: bggId,
                detailsJson: detailsJson,
                fetchedAt: fetchedAt,
                lastViewedAt: lastViewedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GamesTable, GameRow>(table),
                  $$GamesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({barcodeMatchesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (barcodeMatchesRefs) db.barcodeMatches,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (barcodeMatchesRefs)
                    await $_getPrefetchedData<
                      GameRow,
                      $GamesTable,
                      BarcodeMatchRow
                    >(
                      currentTable: table,
                      referencedTable: $$GamesTableReferences
                          ._barcodeMatchesRefsTable(db),
                      managerFromTypedResult: (p0) => $$GamesTableReferences(
                        db,
                        table,
                        p0,
                      ).barcodeMatchesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.gameId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, $$GamesTableReferences),
      GameRow,
      PrefetchHooks Function({bool barcodeMatchesRefs})
    >;
typedef $$BarcodeMatchesTableCreateCompanionBuilder =
    BarcodeMatchesCompanion Function({
      required String gtin13,
      required int gameId,
      required DateTime confirmedAt,
      Value<int> rowid,
    });
typedef $$BarcodeMatchesTableUpdateCompanionBuilder =
    BarcodeMatchesCompanion Function({
      Value<String> gtin13,
      Value<int> gameId,
      Value<DateTime> confirmedAt,
      Value<int> rowid,
    });

final class $$BarcodeMatchesTableReferences
    extends
        BaseReferences<_$AppDatabase, $BarcodeMatchesTable, BarcodeMatchRow> {
  $$BarcodeMatchesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('barcode_matches__game_id__games__id');

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<int>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BarcodeMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BarcodeMatchesTable> {
  $$BarcodeMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gtin13 => $composableBuilder(
    column: $table.gtin13,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get confirmedAt =>
      $composableBuilder(
        column: $table.confirmedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BarcodeMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BarcodeMatchesTable> {
  $$BarcodeMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gtin13 => $composableBuilder(
    column: $table.gtin13,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BarcodeMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BarcodeMatchesTable> {
  $$BarcodeMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gtin13 =>
      $composableBuilder(column: $table.gtin13, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get confirmedAt =>
      $composableBuilder(
        column: $table.confirmedAt,
        builder: (column) => column,
      );

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BarcodeMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BarcodeMatchesTable,
          BarcodeMatchRow,
          $$BarcodeMatchesTableFilterComposer,
          $$BarcodeMatchesTableOrderingComposer,
          $$BarcodeMatchesTableAnnotationComposer,
          $$BarcodeMatchesTableCreateCompanionBuilder,
          $$BarcodeMatchesTableUpdateCompanionBuilder,
          (BarcodeMatchRow, $$BarcodeMatchesTableReferences),
          BarcodeMatchRow,
          PrefetchHooks Function({bool gameId})
        > {
  $$BarcodeMatchesTableTableManager(
    _$AppDatabase db,
    $BarcodeMatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BarcodeMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BarcodeMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BarcodeMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gtin13 = const Value.absent(),
                Value<int> gameId = const Value.absent(),
                Value<DateTime> confirmedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BarcodeMatchesCompanion(
                gtin13: gtin13,
                gameId: gameId,
                confirmedAt: confirmedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gtin13,
                required int gameId,
                required DateTime confirmedAt,
                Value<int> rowid = const Value.absent(),
              }) => BarcodeMatchesCompanion.insert(
                gtin13: gtin13,
                gameId: gameId,
                confirmedAt: confirmedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BarcodeMatchesTable, BarcodeMatchRow>(table),
                  $$BarcodeMatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gameId,
                        referencedTable: $$BarcodeMatchesTableReferences
                            ._gameIdTable(db),
                        referencedColumn: $$BarcodeMatchesTableReferences
                            ._gameIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BarcodeMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BarcodeMatchesTable,
      BarcodeMatchRow,
      $$BarcodeMatchesTableFilterComposer,
      $$BarcodeMatchesTableOrderingComposer,
      $$BarcodeMatchesTableAnnotationComposer,
      $$BarcodeMatchesTableCreateCompanionBuilder,
      $$BarcodeMatchesTableUpdateCompanionBuilder,
      (BarcodeMatchRow, $$BarcodeMatchesTableReferences),
      BarcodeMatchRow,
      PrefetchHooks Function({bool gameId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$BarcodeMatchesTableTableManager get barcodeMatches =>
      $$BarcodeMatchesTableTableManager(_db, _db.barcodeMatches);
}
