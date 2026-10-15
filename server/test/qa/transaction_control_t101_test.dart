import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA round 1 for T-101: edge cases for function body mode, unclosed bodies,
/// number-then-$ dollar quotes, and messages that never hold SQL. Pure Dart.

String? stmt(String sql) => scanTransactionControl(sql).statement;
bool unclosed(String sql) => scanTransactionControl(sql).unclosedBody;

const _body = 'BEGIN ATOMIC SELECT 1; SELECT 2; END';

void main() {
  group('CREATE [OR REPLACE] FUNCTION|PROCEDURE opens body mode', () {
    final heads = <String, String>{
      'function': 'CREATE FUNCTION f() RETURNS int LANGUAGE sql',
      'procedure': 'CREATE PROCEDURE p() LANGUAGE sql',
      'or replace function':
          'CREATE OR REPLACE FUNCTION f() RETURNS int LANGUAGE sql',
      'or replace procedure': 'CREATE OR REPLACE PROCEDURE p() LANGUAGE sql',
      'lower case': 'create or replace function f() returns int language sql',
      'mixed case': 'Create Or Replace Function f() Returns int Language sql',
      'many spaces': 'CREATE   OR   REPLACE   FUNCTION   f()  LANGUAGE sql',
      'tabs and newlines':
          'CREATE\tOR\nREPLACE\r\nFUNCTION\u000bf() LANGUAGE sql',
      'comments between words':
          'CREATE /* a */ OR /* b */ REPLACE -- c\n FUNCTION f() LANGUAGE sql',
      'nested comment': 'CREATE /* a /* b */ c */ FUNCTION f() LANGUAGE sql',
      'comment glued': 'CREATE/**/FUNCTION f() LANGUAGE sql',
      'schema-qualified name': 'CREATE FUNCTION public.f() LANGUAGE sql',
      'quoted name with ; and (': 'CREATE FUNCTION "f;(x" () LANGUAGE sql',
      'default value with a paren in a string':
          "CREATE FUNCTION f(a text DEFAULT ')') RETURNS int LANGUAGE sql",
      'default value in parentheses':
          'CREATE FUNCTION f(a int DEFAULT (1 + (2))) RETURNS int LANGUAGE sql',
      'RETURNS TABLE with begin and atomic columns':
          'CREATE FUNCTION f() RETURNS TABLE (begin int, atomic int) '
          'LANGUAGE sql',
      'RETURNS TABLE with a type named atomic':
          'CREATE FUNCTION f() RETURNS TABLE (begin atomic) LANGUAGE sql',
      'argument named begin of type atomic':
          'CREATE FUNCTION f(begin atomic) RETURNS int LANGUAGE sql',
      'options before the body':
          'CREATE FUNCTION f() RETURNS int LANGUAGE sql STRICT '
          'SECURITY DEFINER SET search_path = public',
    };
    heads.forEach((name, head) {
      test('$name: body passes and a COMMIT after END is reported', () {
        expect(stmt('$head $_body;'), isNull);
        expect(unclosed('$head $_body;'), isFalse);
        expect(stmt('$head $_body; COMMIT;'), 'COMMIT');
        expect(stmt('$head $_body;COMMIT'), 'COMMIT');
        expect(stmt('$head $_body\n;\nROLLBACK'), 'ROLLBACK');
      });
      test('$name: lower and upper case of the body words', () {
        expect(stmt('$head begin atomic select 1; select 2; end;'), isNull);
        expect(
          stmt('$head Begin Atomic select 1; end; commit'),
          'commit'.toUpperCase(),
        );
        expect(stmt('$head BEGIN\n\tATOMIC SELECT 1; END;'), isNull);
        expect(stmt('$head BEGIN /* x */ ATOMIC SELECT 1; END;'), isNull);
        expect(stmt('$head BEGIN -- x\n ATOMIC SELECT 1; END;'), isNull);
      });
    });

    test('a body with a missing semicolon at the very end passes', () {
      expect(
        stmt('CREATE FUNCTION f() LANGUAGE sql BEGIN ATOMIC SELECT 1; END'),
        isNull,
      );
    });
  });

  group('body contents do not confuse the scanner', () {
    const head = 'CREATE FUNCTION f() RETURNS int LANGUAGE sql';

    test('begin and atomic as column names inside the body', () {
      expect(
        stmt('$head BEGIN ATOMIC SELECT begin, atomic FROM t; END; COMMIT;'),
        'COMMIT',
      );
    });

    test('labels, strings, and comments that look like END or COMMIT', () {
      for (final inner in [
        "SELECT 'END; COMMIT;'",
        'SELECT 1 /* END; COMMIT; */',
        'SELECT 1 -- END; COMMIT;\n',
        'SELECT "end", "case", "commit" FROM t',
        r"SELECT $$ END; COMMIT; $$",
        r"SELECT $q$ END $$ ; COMMIT $q$",
        "SELECT E'\\' END; COMMIT;'",
        'SELECT 1 AS atomic',
      ]) {
        expect(
          stmt('$head BEGIN ATOMIC $inner; SELECT 2; END;'),
          isNull,
          reason: inner,
        );
        expect(
          unclosed('$head BEGIN ATOMIC $inner; SELECT 2; END;'),
          isFalse,
          reason: inner,
        );
        expect(
          stmt('$head BEGIN ATOMIC $inner; SELECT 2; END; COMMIT;'),
          'COMMIT',
          reason: inner,
        );
      }
    });

    test('nested CASE ... END to several levels', () {
      const nested =
          'SELECT CASE WHEN a THEN CASE WHEN b THEN CASE WHEN c THEN 1 END END END';
      expect(stmt('$head BEGIN ATOMIC $nested; SELECT 2; END;'), isNull);
      expect(
        stmt('$head BEGIN ATOMIC $nested; SELECT 2; END; COMMIT'),
        'COMMIT',
      );
      expect(
        stmt(
          '$head BEGIN ATOMIC SELECT CASE WHEN a THEN 1 END, CASE WHEN b THEN 2 END; END; COMMIT',
        ),
        'COMMIT',
      );
    });

    test('lower-case and spaced CASE/END', () {
      expect(
        stmt(
          '$head begin atomic select case when true then 1 end ; end ; rollback',
        ),
        'ROLLBACK',
      );
      expect(
        stmt(
          '$head BEGIN ATOMIC SELECT CASE\nWHEN a THEN 1\nEND\n; END; ABORT',
        ),
        'ABORT',
      );
    });

    test('words that merely contain case or end do not count', () {
      expect(
        stmt(
          '$head BEGIN ATOMIC SELECT casefile, ended, end_date, case_x, endpoint FROM t; END; COMMIT',
        ),
        'COMMIT',
      );
    });

    test('AS end and AS case inside a body are labels: the body ends at the '
        'real END and a COMMIT after it is reported', () {
      expect(
        stmt('$head BEGIN ATOMIC SELECT 1 AS end; SELECT 2; END;'),
        isNull,
      );
      expect(
        unclosed('$head BEGIN ATOMIC SELECT 1 AS end; SELECT 2; END;'),
        isFalse,
      );
      final sql = '$head BEGIN ATOMIC SELECT 1 AS case; SELECT 2; END; COMMIT;';
      expect(stmt(sql), 'COMMIT');
      expect(unclosed(sql), isFalse);
    });

    test('a RETURN-style function (no BEGIN ATOMIC) ends at its semicolon', () {
      expect(stmt('$head RETURN (SELECT 1); COMMIT;'), 'COMMIT');
      expect(stmt('$head RETURN 1; SELECT 1;'), isNull);
    });

    test('a plpgsql body in dollar quotes is never body mode', () {
      expect(
        stmt(
          r'CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $$ BEGIN ATOMIC SELECT 1; COMMIT; END $$; COMMIT;',
        ),
        'COMMIT',
      );
      expect(
        stmt(
          r"CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS 'BEGIN ATOMIC SELECT 1; END';",
        ),
        isNull,
      );
    });
  });

  group('several bodies in one migration', () {
    const f = 'CREATE FUNCTION f() RETURNS int LANGUAGE sql';
    const g = 'CREATE OR REPLACE FUNCTION g() RETURNS int LANGUAGE sql';
    const p = 'CREATE PROCEDURE p() LANGUAGE sql';

    test('function, procedure, function all pass', () {
      final sql = '$f $_body; $p $_body; $g $_body;';
      expect(stmt(sql), isNull);
      expect(unclosed(sql), isFalse);
    });

    test('a COMMIT between two bodies is reported', () {
      expect(stmt('$f $_body; COMMIT; $g $_body;'), 'COMMIT');
    });

    test('a COMMIT after the last of three bodies is reported', () {
      expect(stmt('$f $_body; $p $_body; $g $_body; COMMIT;'), 'COMMIT');
    });

    test('a plain statement between bodies is scanned normally', () {
      expect(
        stmt('$f $_body; CREATE TABLE t (i int); ROLLBACK; $g $_body;'),
        'ROLLBACK',
      );
    });

    test('a begin atomic statement between two bodies does not carry the '
        'body mode over', () {
      expect(
        stmt(
          '$f $_body; SELECT begin atomic FROM (SELECT 1 AS begin) s; COMMIT; $g $_body;',
        ),
        'COMMIT',
      );
    });

    test('body mode does not leak past the final END into the next '
        'statement', () {
      expect(stmt('$f $_body; SELECT 1; SAVEPOINT s;'), 'SAVEPOINT');
    });

    test('the second body unclosed is detected', () {
      final sql = '$f $_body; $g BEGIN ATOMIC SELECT 1;';
      expect(unclosed(sql), isTrue);
      expect(stmt(sql), isNull);
    });

    test('the first body unclosed swallows the second as nested text', () {
      final sql = '$f BEGIN ATOMIC SELECT 1; $g $_body;';
      // First END closes the first body; the second function is then at top
      // level with an empty tail, so it ends cleanly. What matters: no
      // hidden COMMIT slips by.
      expect(stmt('$sql COMMIT;') != null || unclosed('$sql COMMIT;'), isTrue);
    });

    test('a thousand functions in one migration scan quickly', () {
      final sql = List.filled(1000, '$f $_body;').join('\n');
      final watch = Stopwatch()..start();
      expect(stmt(sql), isNull);
      expect(unclosed(sql), isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('begin atomic outside a routine statement', () {
    final kinds = <String, String>{
      'select': 'SELECT begin atomic FROM (SELECT 1 AS begin) s',
      'select with label': 'SELECT 1 AS atomic, begin',
      'insert': 'INSERT INTO t (begin, atomic) VALUES (1, 2)',
      'update': 'UPDATE t SET begin = 1, atomic = 2',
      'create table': 'CREATE TABLE t (begin int, atomic int)',
      'create table named function':
          'CREATE TABLE function (begin int, atomic int)',
      'create view': 'CREATE VIEW v AS SELECT begin atomic FROM t',
      'create view named function':
          'CREATE VIEW function AS SELECT begin atomic FROM t',
      'create or replace view named function':
          'CREATE OR REPLACE VIEW function AS SELECT begin atomic FROM t',
      'create type': 'CREATE TYPE function AS (begin int, atomic int)',
      'create trigger': 'CREATE TRIGGER t BEFORE INSERT ON x FOR EACH ROW EXECUTE FUNCTION f(begin atomic)',
      'comment on function':
          "COMMENT ON FUNCTION f() IS 'x'; SELECT begin atomic FROM t",
      'drop function': 'DROP FUNCTION f; SELECT begin atomic',
      'alter function': 'ALTER FUNCTION f() RENAME TO g; SELECT begin atomic',
      'grant on function':
          'GRANT EXECUTE ON FUNCTION f() TO x; SELECT begin atomic',
      'create index on function expr':
          'CREATE INDEX i ON t ((function(begin))); SELECT begin atomic',
      'create aggregate':
          'CREATE AGGREGATE function (int) (sfunc = f, stype = int)',
      'do block': r"DO $$ BEGIN PERFORM 1; END $$; SELECT begin atomic",
      'with':
          'WITH begin AS (SELECT 1 AS atomic) SELECT begin atomic FROM begin',
      'call': 'CALL p(begin atomic)',
      'explain': 'EXPLAIN SELECT begin atomic',
    };
    kinds.forEach((name, sql) {
      for (final variant in [sql, sql.toLowerCase(), sql.toUpperCase()]) {
        test(
          '$name: ${variant == sql
              ? 'as written'
              : variant == sql.toLowerCase()
              ? 'lower'
              : 'upper'}',
          () {
            expect(stmt('$variant; ROLLBACK;'), 'ROLLBACK');
            expect(stmt('$variant; COMMIT; SELECT 1;'), 'COMMIT');
            expect(unclosed('$variant; SELECT 1;'), isFalse);
          },
        );
      }
    });

    test('create or replace with another object kind is not a routine', () {
      for (final kind in ['VIEW', 'TRIGGER', 'RULE', 'TABLE', 'LANGUAGE']) {
        expect(
          stmt('CREATE OR REPLACE $kind x AS SELECT begin atomic; COMMIT;'),
          'COMMIT',
          reason: kind,
        );
      }
    });

    test('CREATE EXTENSION and other words at position 1 are not routines', () {
      expect(
        stmt('CREATE EXTENSION function; SELECT begin atomic; COMMIT'),
        'COMMIT',
      );
      expect(
        stmt('CREATE SCHEMA procedure; SELECT begin atomic; COMMIT'),
        'COMMIT',
      );
    });

    test('FUNCTION at position 2 or 4 does not make a routine', () {
      expect(
        stmt('CREATE TEMP FUNCTION f() BEGIN ATOMIC SELECT 1; COMMIT; END'),
        'COMMIT',
      );
      expect(
        stmt('CREATE OR REPLACE VIEW FUNCTION BEGIN ATOMIC SELECT 1; COMMIT'),
        'COMMIT',
      );
    });

    test('begin atomic inside parentheses of a routine head does not open '
        'a body, the real body afterwards still does', () {
      const sql =
          'CREATE FUNCTION f(a begin, b atomic) RETURNS TABLE (begin atomic) '
          'LANGUAGE sql BEGIN ATOMIC SELECT 1; SELECT 2; END; COMMIT;';
      expect(stmt(sql), 'COMMIT');
      expect(unclosed(sql), isFalse);
    });

    test('begin atomic in parentheses before a COMMIT is not a body', () {
      expect(
        stmt(
          'CREATE FUNCTION f( begin atomic ) RETURNS int LANGUAGE sql RETURN 1; COMMIT;',
        ),
        'COMMIT',
      );
      expect(stmt('SELECT (begin atomic) FROM t; COMMIT;'), 'COMMIT');
      expect(stmt('SELECT f((begin atomic)); COMMIT;'), 'COMMIT');
    });

    test('unbalanced parentheses never hide a COMMIT', () {
      expect(
        stmt('CREATE FUNCTION f( BEGIN ATOMIC SELECT 1; COMMIT;'),
        'COMMIT',
      );
      expect(
        stmt(
          'CREATE FUNCTION f()) LANGUAGE sql BEGIN ATOMIC SELECT 1; END; COMMIT',
        ),
        'COMMIT',
      );
      expect(
        stmt(
          'CREATE FUNCTION f(((((x)))))) LANGUAGE sql BEGIN ATOMIC SELECT 1; END; COMMIT',
        ),
        'COMMIT',
      );
    });
  });

  group('unclosed bodies', () {
    const head = 'CREATE FUNCTION f() RETURNS int LANGUAGE sql';

    test('the ticket example', () {
      expect(unclosed('$head BEGIN ATOMIC SELECT 1;'), isTrue);
    });

    for (final sql in [
      '$head BEGIN ATOMIC',
      '$head BEGIN ATOMIC SELECT 1',
      '$head BEGIN ATOMIC SELECT 1;',
      '$head BEGIN ATOMIC SELECT CASE WHEN a THEN 1 END;',
      '$head BEGIN ATOMIC SELECT CASE WHEN a THEN 1;',
      "$head BEGIN ATOMIC SELECT 'END';",
      '$head BEGIN ATOMIC SELECT 1; /* END */',
      '$head BEGIN ATOMIC SELECT 1; -- END',
      '$head BEGIN ATOMIC SELECT "END";',
      '$head BEGIN ATOMIC SELECT \$\$ END \$\$;',
      'CREATE OR REPLACE PROCEDURE p() LANGUAGE sql BEGIN ATOMIC SELECT 1;',
      '$head $_body; $head BEGIN ATOMIC SELECT 1;',
    ]) {
      test('unclosed: ${sql.replaceAll('\n', ' ')}', () {
        expect(unclosed(sql), isTrue);
      });
    }

    for (final sql in [
      '$head BEGIN ATOMIC SELECT 1; END',
      '$head BEGIN ATOMIC SELECT 1; END;',
      '$head BEGIN ATOMIC END',
      '$head BEGIN ATOMIC SELECT CASE WHEN a THEN 1 END; END',
      '$head BEGIN ATOMIC SELECT 1; end',
    ]) {
      test('closed: ${sql.replaceAll('\n', ' ')}', () {
        expect(unclosed(sql), isFalse);
      });
    }

    test('a COMMIT inside an open body is hidden but the body is flagged', () {
      final sql = '$head BEGIN ATOMIC SELECT 1; COMMIT; SELECT 2;';
      expect(stmt(sql), isNull);
      expect(unclosed(sql), isTrue);
      expect(
        () => validateMigrations([Migration(version: 1, name: 'x', sql: sql)]),
        throwsA(isA<MigrationStateException>()),
      );
    });

    test('empty, whitespace, and comment-only SQL is neither', () {
      for (final sql in ['', '   ', '-- x', '/* x */', ';;;']) {
        expect(stmt(sql), isNull);
        expect(unclosed(sql), isFalse);
      }
    });

    test('the result is a record with both fields', () {
      final scan = scanTransactionControl('SELECT 1');
      expect(scan.statement, isNull);
      expect(scan.unclosedBody, isFalse);
      final found = scanTransactionControl('COMMIT');
      expect(found.statement, 'COMMIT');
      expect(found.unclosedBody, isFalse);
    });
  });

  group('validateMigrations messages never hold SQL', () {
    const marker = 'SECRETMARK_t101';

    Never fail2() => throw StateError('unreachable');

    String message(List<Migration> list) {
      try {
        validateMigrations(list);
      } on MigrationStateException catch (e) {
        return e.message;
      }
      fail2();
    }

    test('unclosed body names version and name, not the SQL', () {
      final text = message([
        const Migration(
          version: 1,
          name: 'fine',
          sql: 'CREATE TABLE a (i int);',
        ),
        const Migration(
          version: 2,
          name: 'open_body',
          sql:
              'CREATE FUNCTION $marker() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1;',
        ),
      ]);
      expect(
        text,
        allOf(contains('2'), contains('open_body'), contains('not closed')),
      );
      expect(text, isNot(contains(marker)));
      expect(text, isNot(contains('SELECT')));
    });

    test('a transaction control statement names version and name, not the '
        'SQL', () {
      final text = message([
        const Migration(
          version: 1,
          name: 'has_commit',
          sql: 'SELECT $marker FROM t; COMMIT;',
        ),
      ]);
      expect(
        text,
        allOf(contains('1'), contains('has_commit'), contains('COMMIT')),
      );
      expect(text, isNot(contains(marker)));
    });

    test('the AC1 probe names version 1 and the name', () {
      final text = message([
        const Migration(
          version: 1,
          name: 'probe',
          sql: 'SELECT begin atomic FROM (SELECT 1 AS begin) s; COMMIT; SELECT 1;',
        ),
      ]);
      expect(text, allOf(contains('1'), contains('probe'), contains('COMMIT')));
    });

    test('a control statement wins over an unclosed body in the same '
        'migration, and the first bad migration wins over a later one', () {
      final both = message([
        const Migration(
          version: 1,
          name: 'both',
          sql: 'COMMIT; CREATE FUNCTION f() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1;',
        ),
      ]);
      expect(both, contains('COMMIT'));
      final order = message([
        const Migration(
          version: 1,
          name: 'first_bad',
          sql: 'CREATE FUNCTION f() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1;',
        ),
        const Migration(version: 2, name: 'second_bad', sql: 'COMMIT;'),
      ]);
      expect(order, contains('first_bad'));
    });

    test('a valid list with bodies passes', () {
      expect(
        () => validateMigrations([
          const Migration(
            version: 1,
            name: 'a',
            sql: 'CREATE FUNCTION f() RETURNS int LANGUAGE sql BEGIN ATOMIC SELECT 1; END;',
          ),
          const Migration(
            version: 2,
            name: 'b',
            sql: 'CREATE OR REPLACE PROCEDURE p() LANGUAGE sql BEGIN ATOMIC SELECT 1; END;',
          ),
        ]),
        returnsNormally,
      );
    });
  });

  group('a \$ after a number opens a dollar quote (R3-G2)', () {
    test('the reviewer probe: COMMIT is reported, the later quote is text', () {
      expect(stmt(r'SELECT 1$$ $$; COMMIT; SELECT $$x$$;'), 'COMMIT');
    });

    final quoted = <String, String>{
      'integer': r'SELECT 1$$ ; COMMIT; $$',
      'decimal': r'SELECT 1.5$$ ; COMMIT; $$',
      'leading dot': r'SELECT .5$$ ; COMMIT; $$',
      'trailing dot': r'SELECT 1.$$ ; COMMIT; $$',
      'hex': r'SELECT 0x1F$$ ; COMMIT; $$',
      'octal and binary':
          r'SELECT 0o17$$ ; COMMIT; $$ ; SELECT 0b11$$ ; COMMIT; $$',
      'exponent': r'SELECT 1e5$$ ; COMMIT; $$',
      'underscores': r'SELECT 1_000$$ ; COMMIT; $$',
      'tagged': r'SELECT 1$a$ ; COMMIT; $a$',
      'parameter': r'SELECT $1$$ ; COMMIT; $$',
      'multi-digit parameter': r'SELECT $12$$ ; COMMIT; $$',
      'after a string': r"SELECT 'a'$$ ; COMMIT; $$",
      'after a quoted identifier': r'SELECT "a"$$ ; COMMIT; $$',
      'after a closing paren': r'SELECT (1)$$ ; COMMIT; $$',
    };
    quoted.forEach((name, sql) {
      test('$name: the quote hides its COMMIT', () {
        expect(stmt(sql), isNull, reason: sql);
      });
    });

    test('identifiers keep their own dollar signs', () {
      expect(stmt(r'SELECT a1$$ ; COMMIT; x'), 'COMMIT');
      expect(stmt(r'SELECT a$b$ ; COMMIT'), 'COMMIT');
      expect(stmt(r'SELECT _$$; COMMIT'), 'COMMIT');
      expect(stmt(r'SELECT é$$; COMMIT'), 'COMMIT');
    });

    test('a parameter is not a quote', () {
      expect(stmt(r'SELECT $1; COMMIT;'), 'COMMIT');
      expect(stmt(r'SELECT $1, $2, $10; COMMIT;'), 'COMMIT');
      expect(stmt(r'SELECT $1 + $2; ROLLBACK'), 'ROLLBACK');
      expect(stmt(r'SELECT $1$ ; COMMIT; $1$'), 'COMMIT');
    });

    test('a lone dollar, or a dollar at the end of input, is harmless', () {
      expect(stmt(r'SELECT $; COMMIT'), 'COMMIT');
      expect(stmt(r'SELECT 1$'), isNull);
      expect(stmt(r'SELECT 1$a'), isNull);
      expect(stmt(r'$'), isNull);
      expect(stmt(r'1$$'), isNull);
    });

    test('an unterminated dollar quote swallows the rest (PostgreSQL rejects '
        'the migration)', () {
      expect(stmt(r'SELECT 1$$ ; COMMIT;'), isNull);
    });

    test('numbers followed by comments or operators end cleanly', () {
      expect(stmt('SELECT 1--c\n; COMMIT'), 'COMMIT');
      expect(stmt('SELECT 1/*c*/; COMMIT'), 'COMMIT');
      expect(stmt('SELECT 1+2*3-4; COMMIT'), 'COMMIT');
      expect(stmt('SELECT 1,2,3; COMMIT'), 'COMMIT');
      expect(stmt('SELECT 1e+5; COMMIT'), 'COMMIT');
      expect(stmt('SELECT 1::int; COMMIT'), 'COMMIT');
    });

    test(
      'a number token glued to letters does not eat a following statement',
      () {
        expect(stmt('SELECT 1abc; COMMIT'), 'COMMIT');
        expect(stmt('SELECT 12 ; COMMIT'), 'COMMIT');
      },
    );

    test('number then dollar quote inside a routine body keeps body mode', () {
      const sql =
          r'CREATE FUNCTION f() RETURNS text LANGUAGE sql BEGIN ATOMIC SELECT 1$$ END; $$; SELECT 2; END; COMMIT;';
      expect(stmt(sql), 'COMMIT');
      expect(unclosed(sql), isFalse);
    });
  });

  group('earlier T-019 behavior is intact', () {
    test('every spelling at statement start is still refused', () {
      for (final w in [
        'BEGIN',
        'COMMIT',
        'END',
        'ROLLBACK',
        'ABORT',
        'SAVEPOINT s',
        'RELEASE s',
        'START TRANSACTION',
        'PREPARE TRANSACTION',
        'COMMIT AND CHAIN',
        'ROLLBACK TO s',
      ]) {
        expect(stmt('SELECT 1; $w'), isNotNull, reason: w);
        expect(stmt('$w;'), isNotNull, reason: w);
      }
    });

    test('findTransactionControl still returns the plain string', () {
      expect(findTransactionControl('SELECT 1; commit'), 'COMMIT');
      expect(findTransactionControl('SELECT 1'), isNull);
    });

    test('the real migrations pass', () {
      expect(() => validateMigrations(schemaMigrations), returnsNormally);
    });
  });
}
