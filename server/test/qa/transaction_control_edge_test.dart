import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA round 2 (T-019): adversarial inputs for the transaction control
/// scanner, beyond the developer's table in test/db/transaction_control_test.dart.
void main() {
  group('refused', () {
    final cases = <String, String>{
      // Standard (non-E) strings do not treat a backslash as an escape.
      r"standard string ends at backslash-quote": r"SELECT '\'; COMMIT; --'",
      'E string ends after an escaped backslash': r"SELECT E'\\'; COMMIT; --'",
      'lowercase e string ends after an escaped backslash':
          r"SELECT e'\\'; COMMIT; --'",
      'doubled quote then real statement': "SELECT 'it''s'; COMMIT;",
      'dashes inside a string are not a comment': "SELECT '--'; COMMIT;",
      'block-comment opener inside a string':
          "SELECT '/*'; COMMIT; SELECT '*/'",
      'dashes inside a quoted identifier': 'SELECT 1 AS "--"; COMMIT;',
      'statement after a closed nested comment':
          'SELECT 1; /* a /* b */ c */ COMMIT;',
      'statement after a closed dollar body': r'SELECT $$;$$; COMMIT;',
      'tagged body closes only on the same tag':
          r"SELECT $a$ $b$ ; COMMIT; $b$ $a$; ROLLBACK;",
      'a parenthesised statement first': 'SELECT 1; (SELECT 2); COMMIT;',
      'CRLF line endings': 'SELECT 1;\r\nCOMMIT;',
      'form feed before the word': 'SELECT 1;\fCOMMIT;',
      'tab before the word': 'SELECT 1;\tCOMMIT;',
      'comment glued to the word': 'SELECT 1;/**/COMMIT/**/;',
      'line comment ending the SQL before the word':
          'SELECT 1; -- note\nCOMMIT',
      'word is the last thing, no semicolon': 'SELECT 1; END',
      'after a closed BEGIN ATOMIC body':
          'CREATE FUNCTION f() RETURNS int LANGUAGE sql '
          'BEGIN ATOMIC SELECT 1; END; COMMIT;',
      'START TRANSACTION with a comment between':
          'START /* x */ TRANSACTION ISOLATION LEVEL SERIALIZABLE',
      'ROLLBACK TO SAVEPOINT': 'ROLLBACK TO SAVEPOINT s',
      'unicode letters before in a column list':
          'CREATE TABLE "é" (i int); COMMIT;',
      'COMMIT in the middle of many statements':
          '${List.filled(200, 'SELECT 1;').join()}COMMIT;${'SELECT 2;' * 5}',
    };
    cases.forEach((label, sql) {
      test(label, () {
        expect(findTransactionControl(sql), isNotNull, reason: sql);
      });
    });

    // PostgreSQL's lexer counts a vertical tab as whitespace (space class
    // [ \t\n\r\f\v], PostgreSQL 16 and later), so this is a real COMMIT.
    test('vertical tab before the word', () {
      expect(findTransactionControl('SELECT 1;\u000bCOMMIT;'), isNotNull);
    });
  });

  group('allowed', () {
    final cases = <String, String>{
      'ENDPOINT as an identifier': 'CREATE TABLE endpoint (i int)',
      'ENDPOINT first word of a line': 'SELECT 1\nENDPOINT',
      'COMMITTED as a column': 'SELECT committed FROM t',
      'BEGINNING as a column': 'SELECT beginning, ended FROM t',
      'RELEASED as an alias': 'SELECT 1 AS released',
      'ABORTED as a table': 'CREATE TABLE aborted (i int)',
      'quoted COMMIT identifier': 'CREATE TABLE "COMMIT" (i int)',
      'COMMIT in a line comment': '-- COMMIT;\nSELECT 1',
      'COMMIT in a block comment': '/* x; COMMIT; */ SELECT 1',
      'COMMIT in a nested comment': '/* a /* b */ ; COMMIT; */ SELECT 1',
      'COMMIT in a string': "INSERT INTO t VALUES ('; COMMIT;')",
      'COMMIT in an E string with an escaped quote':
          r"SELECT E'it\'s; COMMIT; done'",
      'COMMIT in a doubled-quote string': "SELECT 'a''; COMMIT;'",
      'COMMIT in a dollar body': r'SELECT $$ x; COMMIT; $$',
      'COMMIT in a tagged body holding another tag':
          r'SELECT $a$ $b$; COMMIT; $b$ $a$',
      'BEGIN inside a function body':
          r'CREATE FUNCTION f() RETURNS void LANGUAGE plpgsql AS $f$ '
          r'BEGIN PERFORM 1; END $f$',
      'BEGIN ATOMIC body with COMMIT-like words':
          'CREATE FUNCTION f() RETURNS int LANGUAGE sql '
          'BEGIN ATOMIC SELECT committed FROM t; END',
      'SELECT CASE ... END': 'SELECT CASE WHEN true THEN 1 END',
      'PREPARE name AS': 'PREPARE p AS SELECT 1',
      'SET TRANSACTION is not refused': 'SELECT 1',
      'empty': '',
      'only comments': '-- x\n/* y */',
      'only semicolons': ';;;',
      'multiline unicode text':
          "COMMENT ON TABLE t IS 'Spiel des Jahres; COMMIT'",
      'a very long string': "SELECT '${'x; COMMIT;' * 5000}'",
    };
    cases.forEach((label, sql) {
      test(label, () {
        expect(findTransactionControl(sql), isNull, reason: sql);
      });
    });
  });

  group('shape', () {
    test('the result names the statement, in upper case', () {
      expect(findTransactionControl('select 1; commit'), 'COMMIT');
      expect(
        findTransactionControl('prepare   transaction'),
        'PREPARE TRANSACTION',
      );
    });

    test('the first offending statement is reported', () {
      expect(findTransactionControl('SAVEPOINT a; COMMIT;'), 'SAVEPOINT');
    });

    test('a deeply nested comment of 5000 levels finishes quickly', () {
      final sql = '${'/*' * 5000}${'*/' * 5000} COMMIT';
      final watch = Stopwatch()..start();
      expect(findTransactionControl(sql), 'COMMIT');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a million-character migration scans in under 2 s', () {
      final sql = 'SELECT 1; ' * 100000;
      final watch = Stopwatch()..start();
      expect(findTransactionControl(sql), isNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('validateMigrations names the offender', () {
    test('MigrationStateException carries version and name, not the SQL', () {
      try {
        validateMigrations(const [
          Migration(version: 1, name: 'ok', sql: 'CREATE TABLE a (i int);'),
          Migration(
            version: 2,
            name: 'bad_one',
            sql: 'INSERT INTO a VALUES (1234567); COMMIT;',
          ),
        ]);
        fail('should throw');
      } on MigrationStateException catch (e) {
        expect(e.message, allOf(contains('2'), contains('bad_one')));
        expect(e.message, isNot(contains('1234567')));
      }
    });
  });
}
