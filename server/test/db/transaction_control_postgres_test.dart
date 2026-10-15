import 'package:boardgame_server/boardgame_server.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../support/begin_atomic_cases.dart';
import '../support/database.dart';

/// T-101 on real PostgreSQL: the statements the unit tests feed the
/// transaction control scanner are valid SQL, so the scanner's answers are
/// about SQL PostgreSQL would really run, and its view of where a
/// statement ends matches PostgreSQL's.
void main() {
  late ScratchDatabase db;
  late Connection connection;

  setUp(() async {
    db = await TestPostgres.shared.createScratch();
    addTearDown(db.drop);
    connection = await db.connect();
    addTearDown(connection.close);
  });

  Future<void> run(String sql) =>
      connection.execute(sql, queryMode: QueryMode.simple);

  test('AC1: the R3-S1 probe without its COMMIT is valid SQL that selects '
      'one column named atomic', () async {
    final result = await connection.execute(
      'SELECT begin atomic FROM (SELECT 1 AS begin) s',
      queryMode: QueryMode.simple,
    );
    expect(result.schema.columns.single.columnName, 'atomic');
    expect(result.single.single, 1);
  });

  group('AC2: every begin atomic statement kind is valid PostgreSQL and '
      'ends at its semicolon', () {
    for (final MapEntry(key: kind, value: sql)
        in beginAtomicOutsideABody.entries) {
      test(kind, () async {
        await run(beginAtomicOutsideABodySetup);
        // The marker row proves PostgreSQL ran the statement after the
        // `;`, that is the statement ended where the scanner says it ends.
        await run(
          '$sql; CREATE TABLE t101_marker (i int); '
          'INSERT INTO t101_marker VALUES (1);',
        );
        final rows = await connection.execute('SELECT i FROM t101_marker');
        expect(rows.single.single, 1);
      });
    }
  });

  group('AC3: real BEGIN ATOMIC bodies apply in one migration string', () {
    for (final MapEntry(key: label, value: sql) in realRoutineBodies.entries) {
      test(label, () async {
        expect(findTransactionControl(sql), isNull);
        await run(realRoutineBodiesSetup);
        await run('$sql CREATE TABLE t101_after (i int);');
        final rows = await connection.execute(
          "SELECT to_regclass('public.t101_after') IS NOT NULL",
        );
        expect(rows.single.single, isTrue);
      });
    }

    test('the procedure body runs every statement and both CASE '
        'branches', () async {
      await run(realRoutineBodiesSetup);
      await run(realRoutineBodies['CREATE OR REPLACE PROCEDURE']!);
      await run('CALL t101_fill(5); CALL t101_fill(-3);');
      final rows = await connection.execute(
        'SELECT v FROM t101_log ORDER BY v',
      );
      // fill(5): 5 and 6. fill(-3): 0 (the ELSE branch) and -2, which the
      // body's DELETE removes.
      expect(rows.map((r) => r.single), [0, 5, 6]);
    });
  });

  test(r'optional R3-G2: PostgreSQL rejects the number-then-$$ probe as a '
      'whole, so its COMMIT never runs', () async {
    await run('CREATE TABLE t101_g2 (i int)');
    await expectLater(
      run(r'INSERT INTO t101_g2 VALUES (1); SELECT 1$$ $$; COMMIT;'),
      throwsA(isA<ServerException>()),
    );
    final rows = await connection.execute('SELECT count(*) FROM t101_g2');
    expect(rows.single.single, 0);
  });
}
