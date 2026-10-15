import 'dart:math';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA round 2 for T-101: a BEGIN ATOMIC body ends only at an END that is the
/// first token right after ATOMIC or after a `;` inside the body. Pure Dart.

String? stmt(String sql) => scanTransactionControl(sql).statement;
bool unclosed(String sql) => scanTransactionControl(sql).unclosedBody;

const _f = 'CREATE FUNCTION f() RETURNS int LANGUAGE sql';
const _g = 'CREATE OR REPLACE FUNCTION g() RETURNS int LANGUAGE sql';
const _p = 'CREATE PROCEDURE p() LANGUAGE sql';

void main() {
  group('END as the first token of a body statement', () {
    test('an empty body', () {
      expect(stmt('$_f BEGIN ATOMIC END'), isNull);
      expect(unclosed('$_f BEGIN ATOMIC END'), isFalse);
      expect(stmt('$_f BEGIN ATOMIC END; COMMIT'), 'COMMIT');
      expect(stmt('$_f BEGIN ATOMIC END;COMMIT;'), 'COMMIT');
    });

    test('END with and without the final semicolon', () {
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1; END'), isFalse);
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1; END;'), isFalse);
      expect(stmt('$_f BEGIN ATOMIC SELECT 1; END'), isNull);
      expect(stmt('$_f BEGIN ATOMIC SELECT 1; END;'), isNull);
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1;'), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1'), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC'), isTrue);
    });

    test('case of the word END and of the surrounding words', () {
      for (final end in ['END', 'end', 'End', 'eNd', 'enD']) {
        expect(
          stmt('$_f BEGIN ATOMIC SELECT 1; $end; COMMIT;'),
          'COMMIT',
          reason: end,
        );
        expect(
          unclosed('$_f BEGIN ATOMIC SELECT 1; $end'),
          isFalse,
          reason: end,
        );
      }
    });

    test('empty statements inside the body', () {
      for (final sql in [
        '$_f BEGIN ATOMIC ;; SELECT 1;; END; COMMIT',
        '$_f BEGIN ATOMIC ; END; COMMIT',
        '$_f BEGIN ATOMIC ;;;; END; COMMIT',
        '$_f BEGIN ATOMIC SELECT 1; ; ; ; END; COMMIT',
        '$_f BEGIN ATOMIC ;SELECT 1;;END;COMMIT',
      ]) {
        expect(stmt(sql), 'COMMIT', reason: sql);
        expect(unclosed(sql), isFalse, reason: sql);
      }
      expect(unclosed('$_f BEGIN ATOMIC ;; ;'), isTrue);
    });

    test('comments and whitespace between a semicolon and END', () {
      final gaps = [
        ' ',
        '\n',
        '\t',
        '\r\n',
        '\f',
        '\u000b',
        '/* c */',
        '/* a /* nested */ b */',
        '-- note\n',
        '-- note\r',
        ' /* x */ -- y\n\t',
        '/* END; COMMIT; */',
        '-- END; COMMIT;\n',
        '',
      ];
      for (final gap in gaps) {
        final sql = '$_f BEGIN ATOMIC SELECT 1;${gap}END; COMMIT;';
        expect(
          stmt(sql),
          'COMMIT',
          reason: 'gap "${gap.replaceAll('\n', '\\n')}"',
        );
        expect(unclosed(sql), isFalse);
      }
    });

    test('comments and whitespace between ATOMIC and END', () {
      for (final gap in [' ', '/**/', '\n', '-- c\n', '/* END */']) {
        final sql = '$_f BEGIN ATOMIC${gap}END; COMMIT';
        expect(stmt(sql), 'COMMIT', reason: gap);
      }
    });

    test('a comment holding END does not close the body', () {
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1; /* END */'), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC SELECT 1; -- END'), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC /* END */'), isTrue);
    });

    test('a quoted, string, or dollar-quoted END does not close the body', () {
      for (final tok in [
        '"END"',
        '"end"',
        "'END'",
        r'$$END$$',
        r'$t$ END $t$',
      ]) {
        final open = '$_f BEGIN ATOMIC SELECT 1; $tok';
        expect(unclosed(open), isTrue, reason: tok);
        expect(stmt('$open; END; COMMIT'), 'COMMIT', reason: tok);
      }
    });

    test('a statement that starts with a parenthesis then END', () {
      expect(stmt('$_f BEGIN ATOMIC (SELECT 1); END; COMMIT'), 'COMMIT');
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1; (SELECT 2); END; COMMIT'),
        'COMMIT',
      );
    });

    test('END is the first token only after a real semicolon, not one in a '
        'string', () {
      expect(unclosed("$_f BEGIN ATOMIC SELECT ';' END;"), isTrue);
      expect(unclosed("$_f BEGIN ATOMIC SELECT '; END'"), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC SELECT \$\$; END\$\$'), isTrue);
    });
  });

  group('END and CASE inside statements do not matter', () {
    test('a CASE expression ends with its own END', () {
      const body = 'SELECT CASE WHEN a THEN 1 ELSE 2 END';
      expect(stmt('$_f BEGIN ATOMIC $body; SELECT 2; END; COMMIT'), 'COMMIT');
      expect(unclosed('$_f BEGIN ATOMIC $body; SELECT 2; END'), isFalse);
      expect(unclosed('$_f BEGIN ATOMIC $body;'), isTrue);
      expect(unclosed('$_f BEGIN ATOMIC $body'), isTrue);
    });

    test('CASE and END as labels and qualified names', () {
      for (final inner in [
        'SELECT 1 AS end',
        'SELECT 1 AS case',
        'SELECT 1 AS "end"',
        'SELECT 1 AS "case"',
        'SELECT t.end FROM t',
        'SELECT t.case FROM t',
        'SELECT t.end, t.case FROM t',
        'SELECT "end", "case" FROM t',
        'SELECT end_date, case_id, endpoint, casefile FROM t',
        'SELECT x.end AS end, y.case AS case FROM x, y',
        'SELECT 1 AS end, 2 AS case, 3 AS end',
        'SELECT CASE WHEN t.end THEN 1 END AS end FROM t',
        'SELECT CASE WHEN a THEN CASE WHEN b THEN 1 END END AS case',
      ]) {
        expect(
          stmt('$_f BEGIN ATOMIC $inner; SELECT 2; END;'),
          isNull,
          reason: inner,
        );
        expect(
          unclosed('$_f BEGIN ATOMIC $inner; SELECT 2; END;'),
          isFalse,
          reason: inner,
        );
        expect(
          stmt('$_f BEGIN ATOMIC $inner; SELECT 2; END; COMMIT;'),
          'COMMIT',
          reason: inner,
        );
        expect(unclosed('$_f BEGIN ATOMIC $inner;'), isTrue, reason: inner);
      }
    });

    test('lower and upper case of those words', () {
      final inner = 'select 1 as end, t.case from t';
      for (final sql in [inner, inner.toUpperCase()]) {
        expect(stmt('$_f begin atomic $sql; end; commit'), 'COMMIT');
      }
    });

    test('deeply nested parentheses and CASE', () {
      const nested =
          'SELECT ((((CASE WHEN (a) THEN ((CASE WHEN b THEN 1 END)) END))))';
      expect(stmt('$_f BEGIN ATOMIC $nested; END; COMMIT'), 'COMMIT');
      expect(unclosed('$_f BEGIN ATOMIC $nested; END'), isFalse);
      final deep = '${'(' * 200}1${')' * 200}';
      expect(stmt('$_f BEGIN ATOMIC SELECT $deep; END; COMMIT'), 'COMMIT');
    });

    test('unbalanced parentheses inside a body do not stop END from closing '
        'it', () {
      expect(stmt('$_f BEGIN ATOMIC SELECT (1; END; COMMIT'), 'COMMIT');
      expect(stmt('$_f BEGIN ATOMIC SELECT 1); END; COMMIT'), 'COMMIT');
    });

    test('a body statement whose first token is a number or operator', () {
      expect(stmt('$_f BEGIN ATOMIC 1; END; COMMIT'), 'COMMIT');
      expect(stmt('$_f BEGIN ATOMIC -1; END; COMMIT'), 'COMMIT');
      expect(unclosed('$_f BEGIN ATOMIC 1 END'), isTrue);
    });
  });

  group('the reviewer probes and variants', () {
    final labels = ['AS case', 'AS end', 'AS "case"', 'AS CASE', 'as case'];

    test('probe 1: AS case, END; END; is refused as a second END', () {
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END; END; SELECT 1;'),
        'END',
      );
      for (final l in labels) {
        final sql = '$_f BEGIN ATOMIC SELECT 1 $l; END; END; SELECT 1;';
        if (l == 'AS "case"') {
          expect(stmt(sql), 'END', reason: l);
        } else {
          expect(stmt(sql), 'END', reason: l);
        }
      }
    });

    test('probe 2: AS case, END; COMMIT; then a second body', () {
      final sql =
          '$_f BEGIN ATOMIC SELECT 1 AS case; END; COMMIT; '
          '$_g BEGIN ATOMIC SELECT 1; END;';
      expect(stmt(sql), 'COMMIT');
      for (final l in labels) {
        expect(
          stmt(
            '$_f BEGIN ATOMIC SELECT 1 $l; END; COMMIT; $_g BEGIN ATOMIC SELECT 1; END;',
          ),
          'COMMIT',
          reason: l,
        );
      }
    });

    test('probe 3: t.case, END; END;', () {
      expect(
        stmt('$_f BEGIN ATOMIC SELECT t.case FROM t; END; END; SELECT 1;'),
        'END',
      );
      expect(
        stmt('$_f BEGIN ATOMIC SELECT t.case FROM t; END; COMMIT;'),
        'COMMIT',
      );
      expect(
        stmt('$_f BEGIN ATOMIC SELECT t.end FROM t; END; ROLLBACK;'),
        'ROLLBACK',
      );
    });

    test('variants: many labels, repeated END, END right after END', () {
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1 AS case, 2 AS end; END; END;'),
        'END',
      );
      expect(stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END;END;'), 'END');
      expect(stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END ; /**/ END'), 'END');
      expect(stmt('$_f BEGIN ATOMIC SELECT 1 AS end; END; ABORT;'), 'ABORT');
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END; SAVEPOINT s;'),
        'SAVEPOINT',
      );
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END; START TRANSACTION;'),
        'START TRANSACTION',
      );
      expect(
        stmt('$_f BEGIN ATOMIC SELECT 1 AS case; END; COMMIT AND CHAIN;'),
        'COMMIT',
      );
    });

    test('three probes again through validateMigrations', () {
      for (final sql in [
        '$_f BEGIN ATOMIC SELECT 1 AS case; END; END; SELECT 1;',
        '$_f BEGIN ATOMIC SELECT 1 AS case; END; COMMIT; $_g BEGIN ATOMIC SELECT 1; END;',
        '$_f BEGIN ATOMIC SELECT t.case FROM t; END; END; SELECT 1;',
      ]) {
        expect(
          () =>
              validateMigrations([Migration(version: 1, name: 'x', sql: sql)]),
          throwsA(isA<MigrationStateException>()),
          reason: sql,
        );
      }
    });
  });

  group('a second function after a body', () {
    const body = 'BEGIN ATOMIC SELECT 1; END';

    test('function then function, procedure, function', () {
      final sql = '$_f $body; $_p $body; $_g $body;';
      expect(stmt(sql), isNull);
      expect(unclosed(sql), isFalse);
    });

    test('a COMMIT between or after bodies is reported', () {
      expect(stmt('$_f $body; COMMIT; $_g $body;'), 'COMMIT');
      expect(stmt('$_f $body; $_g $body; COMMIT;'), 'COMMIT');
      expect(stmt('$_f $body; $_g $body; $_p $body; ROLLBACK'), 'ROLLBACK');
    });

    test('the second body unclosed is refused as unclosed', () {
      expect(unclosed('$_f $body; $_g BEGIN ATOMIC SELECT 1;'), isTrue);
      expect(unclosed('$_f $body; $_g BEGIN ATOMIC'), isTrue);
    });

    test('the first body unclosed makes the second function part of it, '
        'and the end of input is still flagged', () {
      final sql = '$_f BEGIN ATOMIC SELECT 1; $_g $body;';
      // The first END closes the first body; the rest is then a plain
      // (empty) tail. What matters is that nothing hides a COMMIT.
      expect(stmt('$sql COMMIT;'), 'COMMIT');
    });

    test('a second function whose body has labels named case and end', () {
      final sql =
          '$_f BEGIN ATOMIC SELECT 1 AS case; END; '
          '$_g BEGIN ATOMIC SELECT t.end AS end FROM t; END; COMMIT;';
      expect(stmt(sql), 'COMMIT');
      final clean =
          '$_f BEGIN ATOMIC SELECT 1 AS case; END; '
          '$_g BEGIN ATOMIC SELECT t.end AS end FROM t; END;';
      expect(stmt(clean), isNull);
      expect(unclosed(clean), isFalse);
    });

    test('a non-routine statement mentioning begin atomic between bodies '
        'does not open a body', () {
      final sql =
          '$_f $body; SELECT begin atomic FROM (SELECT 1 AS begin) s; '
          'COMMIT; $_g $body;';
      expect(stmt(sql), 'COMMIT');
    });

    test('state does not leak: after a closed body the next routine starts '
        'clean', () {
      final sql = '$_f $body; $_g $body; SELECT 1 AS end; COMMIT;';
      expect(stmt(sql), 'COMMIT');
    });

    test('a function with RETURN (no body) between two bodies', () {
      final sql = '$_f $body; $_g RETURN 1; $_p $body;';
      expect(stmt(sql), isNull);
      expect(stmt('$_f $body; $_g RETURN 1; COMMIT; $_p $body;'), 'COMMIT');
    });
  });

  group('randomized bodies agree with the grammar rule', () {
    // Statements that are valid inside a body and use every tricky word.
    const bank = [
      'SELECT 1',
      'SELECT 1 AS end',
      'SELECT 1 AS case',
      'SELECT t.end FROM t',
      'SELECT t.case FROM t',
      'SELECT "end", "case" FROM t',
      'SELECT CASE WHEN a THEN 1 END',
      'SELECT CASE WHEN a THEN CASE WHEN b THEN 1 ELSE 2 END END AS end',
      'SELECT end_date, case_id FROM t',
      "SELECT 'END; COMMIT;'",
      'SELECT 1 /* END; COMMIT; */',
      'INSERT INTO t VALUES (1)',
      'UPDATE t SET a = CASE WHEN b THEN 1 END',
      '',
    ];

    String body(Random r) {
      final n = r.nextInt(6);
      final parts = [for (var i = 0; i < n; i++) bank[r.nextInt(bank.length)]];
      return parts.map((p) => '$p;').join(' ');
    }

    test('500 random bodies: clean, then COMMIT, then a second END', () {
      final r = Random(20261015);
      for (var i = 0; i < 500; i++) {
        final b = body(r);
        final head = r.nextBool()
            ? _f
            : _p.replaceFirst('CREATE', 'CREATE OR REPLACE');
        final sql = '$head BEGIN ATOMIC $b END;';
        expect(stmt(sql), isNull, reason: sql);
        expect(unclosed(sql), isFalse, reason: sql);
        expect(stmt('$sql COMMIT;'), 'COMMIT', reason: sql);
        expect(stmt('$sql END;'), 'END', reason: sql);
        expect(
          stmt('$sql $_g BEGIN ATOMIC $b END; ROLLBACK;'),
          'ROLLBACK',
          reason: sql,
        );
        expect(unclosed('$head BEGIN ATOMIC $b'), isTrue, reason: sql);
      }
    });
  });

  group('messages for the new cases', () {
    test('a second END is named as END, with version and name, no SQL', () {
      try {
        validateMigrations(const [
          Migration(
            version: 1,
            name: 'double_end',
            sql:
                'CREATE FUNCTION SECRETMARK_f() RETURNS int LANGUAGE sql '
                'BEGIN ATOMIC SELECT 1 AS case; END; END;',
          ),
        ]);
        fail('should throw');
      } on MigrationStateException catch (e) {
        expect(
          e.message,
          allOf(contains('1'), contains('double_end'), contains('END')),
        );
        expect(e.message, isNot(contains('SECRETMARK')));
      }
    });
  });
}
