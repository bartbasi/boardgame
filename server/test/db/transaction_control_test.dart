import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// T-019 round 2, R1-M1 (QA T-019-B1): a migration must not end or nest the
/// transaction it runs in. findTransactionControl is the scanner and
/// validateMigrations refuses what it finds.
void main() {
  group('findTransactionControl refuses every spelling at statement start', () {
    const refused = {
      'BEGIN': 'BEGIN',
      'BEGIN TRANSACTION': 'BEGIN',
      'BEGIN WORK ISOLATION LEVEL SERIALIZABLE': 'BEGIN',
      'START TRANSACTION': 'START TRANSACTION',
      'START TRANSACTION READ WRITE': 'START TRANSACTION',
      'COMMIT': 'COMMIT',
      'COMMIT WORK': 'COMMIT',
      'COMMIT AND CHAIN': 'COMMIT',
      "COMMIT PREPARED 'tx1'": 'COMMIT',
      'END': 'END',
      'END TRANSACTION': 'END',
      'ROLLBACK': 'ROLLBACK',
      'ROLLBACK AND NO CHAIN': 'ROLLBACK',
      'ROLLBACK TO SAVEPOINT s1': 'ROLLBACK',
      'ROLLBACK TO s1': 'ROLLBACK',
      "ROLLBACK PREPARED 'tx1'": 'ROLLBACK',
      'ABORT': 'ABORT',
      'SAVEPOINT s1': 'SAVEPOINT',
      'RELEASE SAVEPOINT s1': 'RELEASE',
      'RELEASE s1': 'RELEASE',
      "PREPARE TRANSACTION 'tx1'": 'PREPARE TRANSACTION',
    };

    for (final MapEntry(key: statement, value: keyword) in refused.entries) {
      test('$statement, in any case and position', () {
        final variants = {
          statement,
          '$statement;',
          statement.toLowerCase(),
          _mixedCase(statement),
          '  \n\t$statement;',
          'CREATE TABLE a (i int); $statement; SELECT 1/0;',
          'CREATE TABLE a (i int);\n${statement.toLowerCase()}\n;',
          '-- comment\n$statement;',
          '/* comment */ $statement;',
          '/* outer /* nested */ still a comment */$statement;',
          "SELECT ';'; $statement;",
          r'SELECT $$ ; $$; '
              '$statement;',
          'SELECT 1;;$statement',
        };
        for (final sql in variants) {
          expect(findTransactionControl(sql), keyword, reason: sql);
        }
      });
    }

    test('QA T-019-B1: CREATE TABLE sneaky (i int); COMMIT; SELECT 1/0;', () {
      expect(
        findTransactionControl(
          'CREATE TABLE sneaky (i int); COMMIT; SELECT 1/0;',
        ),
        'COMMIT',
      );
    });
  });

  group('findTransactionControl allows', () {
    const allowed = {
      'ordinary DDL':
          'CREATE TABLE games (id bigint); CREATE INDEX i ON g (x);',
      'keywords not at statement start':
          "CREATE TABLE t (commit int, rollback_at timestamptz, \"end\" int);\n"
          'COMMENT ON TABLE t IS NULL;',
      'a column named begin in an UPDATE': 'UPDATE t SET begin = 1;',
      'quoted keyword text':
          "INSERT INTO t VALUES ('a'); SELECT '; COMMIT; '; SELECT 'it''s; "
          "ROLLBACK';",
      'an E string with an escaped quote': r"SELECT E'\'; COMMIT; '; SELECT 1;",
      'a double-quoted identifier with a semicolon':
          'CREATE TABLE "a;commit" (i int); SELECT 1;',
      'a comment that holds a statement':
          '-- ; COMMIT;\nSELECT 1; /* ; ROLLBACK; */ SELECT 2;',
      'a PL/pgSQL function body': r'''
CREATE FUNCTION touch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.x IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$$;
''',
      r'a tagged dollar quote with $$ inside': r'''
CREATE FUNCTION f() RETURNS text LANGUAGE plpgsql AS $body$
BEGIN
  RETURN '$$; COMMIT; $$';
END;
$body$;
''',
      'a DO block': r'''
DO $$
BEGIN
  PERFORM 1;
EXCEPTION WHEN others THEN
  RAISE;
END
$$;
''',
      'a SQL-standard function body': '''
CREATE FUNCTION g(x int) RETURNS int LANGUAGE sql
BEGIN ATOMIC
  SELECT CASE WHEN x > 0 THEN x ELSE 0 END;
  SELECT x + 1;
END;
SELECT 1;
''',
      'PREPARE of a statement (not a transaction)':
          'PREPARE q (int) AS SELECT \$1; DEALLOCATE q;',
      'a column named start': 'SELECT start FROM t; SELECT 1;',
      'an identifier containing a dollar sign':
          r'SELECT a$b$ FROM t; SELECT 1;',
    };

    for (final MapEntry(key: label, value: sql) in allowed.entries) {
      test(label, () {
        expect(findTransactionControl(sql), isNull, reason: sql);
      });
    }

    test('every migration in schemaMigrations', () {
      for (final m in schemaMigrations) {
        expect(findTransactionControl(m.sql), isNull, reason: m.name);
      }
    });

    test('control words after the end of an unterminated quote or comment', () {
      expect(findTransactionControl("SELECT '; COMMIT;"), isNull);
      expect(findTransactionControl('SELECT 1; /* COMMIT;'), isNull);
      expect(findTransactionControl(r'SELECT $x$ ; COMMIT;'), isNull);
      expect(findTransactionControl('SELECT "a; COMMIT;'), isNull);
    });

    test('control words after a SQL-standard body ends are still refused', () {
      expect(
        findTransactionControl('''
CREATE FUNCTION g() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1; END;
COMMIT;
'''),
        'COMMIT',
      );
    });

    test(r'a lone $ or $1 is not a dollar quote', () {
      expect(findTransactionControl(r'SELECT $1; COMMIT;'), 'COMMIT');
      expect(findTransactionControl(r'SELECT 1 $ 2; ROLLBACK;'), 'ROLLBACK');
    });
  });

  group('validateMigrations (T-019 round 2, R1-M1)', () {
    test('refuses a migration with a transaction control statement and '
        'names the migration and the statement', () {
      expect(
        () => validateMigrations(const [
          Migration(version: 1, name: 'ok', sql: 'SELECT 1;'),
          Migration(
            version: 2,
            name: 'sneaky_commit',
            sql: 'CREATE TABLE sneaky (i int); commit; SELECT 1/0;',
          ),
        ]),
        throwsA(
          isA<MigrationStateException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('migration 2 (sneaky_commit)'),
              contains('COMMIT statement'),
              contains('own transaction'),
            ),
          ),
        ),
      );
    });

    test('accepts PL/pgSQL bodies with BEGIN and END', () {
      expect(
        () => validateMigrations(const [
          Migration(
            version: 1,
            name: 'with_function',
            sql: r'''
CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $$
BEGIN
  RETURN 1;
END;
$$;
''',
          ),
        ]),
        returnsNormally,
      );
    });
  });
}

String _mixedCase(String s) => String.fromCharCodes([
  for (var i = 0; i < s.length; i++)
    i.isEven ? s.toLowerCase().codeUnitAt(i) : s.toUpperCase().codeUnitAt(i),
]);
