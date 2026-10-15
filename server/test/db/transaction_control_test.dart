import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/begin_atomic_cases.dart';

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

  group('whitespace and comment ends match the PostgreSQL lexer '
      '(T-019 round 3, QA T-019-R2-B1)', () {
    // scan.l: space [ \t\n\r\f\v], newline [\n\r].
    const spaces = {
      'space (0x20)': 0x20,
      'tab (0x09)': 0x09,
      'line feed (0x0A)': 0x0A,
      'carriage return (0x0D)': 0x0D,
      'form feed (0x0C)': 0x0C,
      'vertical tab (0x0B)': 0x0B,
    };
    for (final MapEntry(key: label, value: code) in spaces.entries) {
      final ws = String.fromCharCode(code);
      test('$label before and after the word is whitespace', () {
        expect(
          findTransactionControl('CREATE TABLE a (i int);${ws}COMMIT;$ws'),
          'COMMIT',
        );
        expect(findTransactionControl('${ws}ROLLBACK'), 'ROLLBACK');
        expect(
          findTransactionControl('SELECT 1;${ws}START${ws}TRANSACTION'),
          'START TRANSACTION',
        );
      });
    }

    test('a -- comment ends at a carriage return as well as a line feed', () {
      expect(findTransactionControl('SELECT 1; -- note\rCOMMIT;'), 'COMMIT');
      expect(findTransactionControl('SELECT 1; -- note\nCOMMIT;'), 'COMMIT');
      expect(findTransactionControl('SELECT 1; -- note\r\nCOMMIT;'), 'COMMIT');
      expect(findTransactionControl('SELECT 1; -- note\fCOMMIT;'), isNull);
      expect(findTransactionControl('SELECT 1; -- note\vCOMMIT;'), isNull);
    });

    test('characters PostgreSQL does not treat as whitespace keep the word '
        'part of another token, as in the lexer', () {
      // A no-break space is an identifier character (>= 0x80) for
      // PostgreSQL, so " COMMIT" is one unknown word there too.
      expect(findTransactionControl('SELECT 1; COMMIT;'), isNull);
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

  _t101();
}

/// The R3-S1 probe from docs/handoffs/T-019.md: `begin` is a column and
/// `atomic` its label, outside any function, then a COMMIT.
const _r3s1Probe =
    'SELECT begin atomic FROM (SELECT 1 AS begin) s; COMMIT; SELECT 1;';

void _t101() {
  group('T-101: function body mode only in CREATE FUNCTION or PROCEDURE', () {
    test('AC1: the R3-S1 probe reports the COMMIT', () {
      expect(findTransactionControl(_r3s1Probe), 'COMMIT');
    });

    test('AC1: validateMigrations refuses the R3-S1 probe and names version '
        '1 and the migration', () {
      expect(
        () => validateMigrations(const [
          Migration(version: 1, name: 'r3_s1_probe', sql: _r3s1Probe),
        ]),
        throwsA(
          isA<MigrationStateException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('migration 1 (r3_s1_probe)'),
              contains('COMMIT statement'),
            ),
          ),
        ),
      );
    });

    group('AC2: begin atomic outside a body does not hide a ROLLBACK', () {
      for (final MapEntry(key: kind, value: sql)
          in beginAtomicOutsideABody.entries) {
        test(kind, () {
          for (final variant in {sql, sql.toLowerCase(), sql.toUpperCase()}) {
            final probe = '$variant; ROLLBACK;';
            expect(findTransactionControl(probe), 'ROLLBACK', reason: probe);
            expect(
              scanTransactionControl('$variant;').unclosedBody,
              isFalse,
              reason: variant,
            );
          }
        });
      }
    });

    group('AC3: real function and procedure bodies', () {
      const bodies = {
        'CREATE FUNCTION': '''
CREATE FUNCTION t101_sum(x int) RETURNS int LANGUAGE sql
BEGIN ATOMIC
  SELECT 1;
  SELECT CASE WHEN x > 0 THEN CASE WHEN x > 9 THEN 9 ELSE x END ELSE 0 END;
END;
''',
        'CREATE OR REPLACE PROCEDURE': '''
CREATE OR REPLACE PROCEDURE t101_fill(x int) LANGUAGE sql
BEGIN ATOMIC
  INSERT INTO t101_log VALUES (CASE WHEN x > 0 THEN x ELSE 0 END);
  INSERT INTO t101_log VALUES (x + 1);
  DELETE FROM t101_log WHERE v < 0;
END;
''',
        'create or replace function, lower case, RETURNS TABLE': '''
create or replace function t101_rows() returns table (v int) language sql
begin atomic
  select 1;
  select case 1 when 1 then 2 end;
end;
''',
        'CREATE PROCEDURE with comments and strings in the body': '''
CREATE PROCEDURE t101_note() LANGUAGE sql
BEGIN ATOMIC
  -- END; COMMIT;
  INSERT INTO t101_log VALUES (length('END; COMMIT;'));
  /* END; */ INSERT INTO t101_log VALUES (2);
END;
''',
      };

      for (final MapEntry(key: label, value: sql) in bodies.entries) {
        test('$label passes', () {
          final scan = scanTransactionControl(sql);
          expect(scan.statement, isNull, reason: sql);
          expect(scan.unclosedBody, isFalse, reason: sql);
          expect(
            () => validateMigrations([
              Migration(version: 1, name: 'body', sql: sql),
            ]),
            returnsNormally,
          );
        });

        test('$label, then a COMMIT after the final END is reported', () {
          expect(findTransactionControl('${sql}COMMIT;'), 'COMMIT');
          expect(
            findTransactionControl('${sql}SELECT 1; ROLLBACK;'),
            'ROLLBACK',
          );
        });
      }
    });

    group('AC4: a body that is not closed is refused', () {
      const unclosed = {
        'no END at all': 'CREATE FUNCTION f() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1;',
        'a CASE END but no body END':
            'CREATE PROCEDURE p() LANGUAGE sql BEGIN ATOMIC '
            'SELECT CASE WHEN true THEN 1 END;',
        'an END hidden in a comment':
            'CREATE FUNCTION f() RETURNS int LANGUAGE sql BEGIN ATOMIC '
            'SELECT 1; -- END;\n',
      };

      for (final MapEntry(key: label, value: sql) in unclosed.entries) {
        test(label, () {
          final scan = scanTransactionControl(sql);
          expect(scan.statement, isNull);
          expect(scan.unclosedBody, isTrue);
          expect(
            () => validateMigrations([
              const Migration(version: 1, name: 'fine', sql: 'SELECT 1;'),
              Migration(version: 2, name: 'open_body', sql: sql),
            ]),
            throwsA(
              isA<MigrationStateException>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('migration 2 (open_body)'),
                  contains('not closed'),
                  isNot(contains('SELECT')),
                  isNot(contains('ATOMIC SELECT')),
                ),
              ),
            ),
          );
        });
      }

      test('the message never contains the SQL', () {
        const sql =
            'CREATE FUNCTION secret_marker_t101() RETURNS int LANGUAGE sql '
            'BEGIN ATOMIC SELECT 1;';
        try {
          validateMigrations(const [
            Migration(version: 1, name: 'open_body', sql: sql),
          ]);
          fail('should throw');
        } on MigrationStateException catch (e) {
          expect(e.message, isNot(contains('secret_marker_t101')));
          expect(e.toString(), isNot(contains('secret_marker_t101')));
        }
      });
    });

    group(r'optional R3-G2: a $ right after a number opens a dollar quote', () {
      const probes = {
        r'the reviewer probe': r'SELECT 1$$ $$; COMMIT; SELECT $$x$$;',
        r'after a decimal': r'SELECT 1.5$$ $$; COMMIT; SELECT $$x$$;',
        r'after a parameter': r'SELECT $1$$ $$; COMMIT; SELECT $$x$$;',
        // Letters belong to the number here (PostgreSQL 16 and later), so
        // the `$` after them is not inside an identifier.
        r'after a hex integer': r'SELECT 0x1F$$ $$; COMMIT; SELECT $$x$$;',
        r'after an exponent': r'SELECT 1e5$$ $$; COMMIT; SELECT $$x$$;',
        r'a tagged quote after a number':
            r'SELECT 10$t$ $t$; COMMIT; SELECT $t$x$t$;',
      };
      for (final MapEntry(key: label, value: sql) in probes.entries) {
        test(label, () {
          // Two dollar quotes hide nothing: the COMMIT sits between them.
          expect(findTransactionControl(sql), 'COMMIT', reason: sql);
        });
      }

      test(r'a $ inside an identifier still is not a quote', () {
        expect(
          findTransactionControl(r'SELECT a$$ FROM t; COMMIT; SELECT $$x$$;'),
          'COMMIT',
        );
        expect(
          findTransactionControl(r'SELECT a1$$ ; COMMIT; $$ FROM t;'),
          'COMMIT',
        );
      });

      test('a dollar quote right after a number hides what is inside it', () {
        expect(findTransactionControl(r'SELECT 1$$; COMMIT;$$;'), isNull);
      });
    });
  });
}

String _mixedCase(String s) => String.fromCharCodes([
  for (var i = 0; i < s.length; i++)
    i.isEven ? s.toLowerCase().codeUnitAt(i) : s.toUpperCase().codeUnitAt(i),
]);
