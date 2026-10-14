import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// QA round 3 (T-019): whitespace and `--` comment ends must match the
/// PostgreSQL lexer (scan.l: space [ \t\n\r\f\v], newline [\n\r]).
void main() {
  const all = [' ', '\t', '\n', '\r', '\f', '\u000b'];

  group('a -- comment ends at LF or CR, so the next word is a statement', () {
    final ends = {'LF': '\n', 'CR': '\r', 'CRLF': '\r\n', 'LF-CR': '\n\r'};
    ends.forEach((name, end) {
      test('$name before COMMIT', () {
        expect(
          findTransactionControl('SELECT 1; -- note${end}COMMIT;'),
          'COMMIT',
        );
      });
      test('$name before COMMIT, comment is the very first thing', () {
        expect(findTransactionControl('-- x${end}COMMIT'), 'COMMIT');
      });
      test('$name before ROLLBACK, with a semicolon in the comment', () {
        expect(
          findTransactionControl('SELECT 1; -- a; b${end}ROLLBACK'),
          'ROLLBACK',
        );
      });
      test('$name ends two stacked comments', () {
        expect(findTransactionControl('-- a$end-- b${end}END'), 'END');
      });
    });

    test('a comment that holds COMMIT and ends at CR hides only itself', () {
      expect(findTransactionControl('SELECT 1; -- COMMIT\rSELECT 2;'), isNull);
      expect(
        findTransactionControl('SELECT 1; -- COMMIT\rSELECT 2; COMMIT'),
        'COMMIT',
      );
    });

    test('a comment at the end of the input with no newline hides COMMIT', () {
      expect(findTransactionControl('SELECT 1; -- COMMIT'), isNull);
    });

    for (final (name, char) in [('FF', '\f'), ('VT', '\u000b')]) {
      test('$name inside a -- comment does not end it', () {
        expect(
          findTransactionControl('SELECT 1; -- a${char}COMMIT\nSELECT 2;'),
          isNull,
        );
        expect(
          findTransactionControl('-- a${char}COMMIT;${char}COMMIT'),
          isNull,
        );
      });
      test('$name then LF ends it', () {
        expect(findTransactionControl('-- a$char\nCOMMIT'), 'COMMIT');
      });
    }

    test('a lone dash or a dash before a number is not a comment', () {
      expect(findTransactionControl('SELECT 1 - 1; COMMIT'), 'COMMIT');
      expect(findTransactionControl('SELECT -1; COMMIT'), 'COMMIT');
      expect(findTransactionControl('SELECT 1 -\n- 1; COMMIT'), 'COMMIT');
    });

    test('a CR inside a string or a block comment does not matter', () {
      expect(findTransactionControl("SELECT '-- a\rCOMMIT';"), isNull);
      expect(findTransactionControl('/* -- a\rCOMMIT */ SELECT 1;'), isNull);
      expect(findTransactionControl('/* a */ -- b\rCOMMIT'), 'COMMIT');
    });
  });

  group('every whitespace run is skipped', () {
    test('each single character, and every pair, between ; and the word', () {
      for (final a in all) {
        expect(findTransactionControl('SELECT 1;${a}COMMIT'), 'COMMIT');
        for (final b in all) {
          expect(
            findTransactionControl('SELECT 1;$a${b}COMMIT'),
            'COMMIT',
            reason: '${a.codeUnitAt(0)} ${b.codeUnitAt(0)}',
          );
        }
      }
    });

    test('a long mixed run', () {
      final run = List.generate(500, (i) => all[i % all.length]).join();
      expect(findTransactionControl('SELECT 1;${run}COMMIT'), 'COMMIT');
      expect(findTransactionControl('${run}SAVEPOINT s'), 'SAVEPOINT');
    });

    test('whitespace between START and TRANSACTION, of every kind', () {
      for (final a in all) {
        expect(
          findTransactionControl('START${a}TRANSACTION'),
          'START TRANSACTION',
        );
        expect(
          findTransactionControl('PREPARE$a$a${a}TRANSACTION'),
          'PREPARE TRANSACTION',
        );
      }
    });

    test('whitespace before the semicolon and after the word', () {
      for (final a in all) {
        expect(findTransactionControl('COMMIT$a;'), 'COMMIT');
        expect(findTransactionControl('SELECT 1$a;${a}END$a'), 'END');
      }
    });
  });

  group('characters PostgreSQL does not treat as whitespace', () {
    // They are >= 0x80, so for PostgreSQL they are identifier characters:
    // "<char>COMMIT" is one unknown word and a syntax error, never a COMMIT.
    final odd = {
      'U+00A0 no-break space': ' ',
      'U+2028 line separator': ' ',
      'U+2029 paragraph separator': ' ',
      'U+3000 ideographic space': '　',
      'U+2003 em space': ' ',
      'U+FEFF zero width no-break': '﻿',
      'U+0085 next line': '\u0085',
      'U+200B zero width space': '​',
    };
    odd.forEach((name, ch) {
      test('$name before COMMIT is part of the word', () {
        expect(findTransactionControl('SELECT 1;${ch}COMMIT;'), isNull);
      });
      test('$name after COMMIT is part of the word', () {
        expect(findTransactionControl('SELECT 1; COMMIT$ch;'), isNull);
      });
      test('$name does not end a -- comment', () {
        expect(findTransactionControl('SELECT 1; -- a${ch}COMMIT'), isNull);
      });
      test('$name inside a quoted name does not hide a real COMMIT', () {
        expect(findTransactionControl('SELECT "a${ch}b"; COMMIT;'), 'COMMIT');
      });
    });

    test('a NUL or other control character is not whitespace either', () {
      expect(findTransactionControl('SELECT 1;\u0001COMMIT'), isNull);
      expect(findTransactionControl('SELECT 1;\u001cCOMMIT'), isNull);
    });
  });

  group('whitespace inside /* */ next to the keyword', () {
    test('every whitespace kind inside the comment is ignored', () {
      for (final a in all) {
        expect(findTransactionControl('SELECT 1;/*$a*/COMMIT'), 'COMMIT');
        expect(findTransactionControl('SELECT 1;/*${a}COMMIT$a*/'), isNull);
        expect(
          findTransactionControl('SELECT 1;/* a */$a/* b */${a}END'),
          'END',
        );
      }
    });

    test('a comment between the two words of START TRANSACTION', () {
      expect(
        findTransactionControl('START/*\r\n*/TRANSACTION'),
        'START TRANSACTION',
      );
    });

    test('a comment right after the word does not hide it', () {
      expect(findTransactionControl('COMMIT/*x*/'), 'COMMIT');
      expect(findTransactionControl('COMMIT--x'), 'COMMIT');
      expect(findTransactionControl('COMMIT--x\rSELECT 1'), 'COMMIT');
    });

    test('a comment glued around the word still finds it', () {
      expect(findTransactionControl('SELECT 1;/**/COMMIT/**/;'), 'COMMIT');
      expect(findTransactionControl('SELECT 1;COMMIT/*x*/ ;'), 'COMMIT');
    });
  });

  test('validateMigrations refuses the CR and VT forms', () {
    for (final sql in [
      'CREATE TABLE a (i int); -- x\rCOMMIT;',
      'CREATE TABLE a (i int);\u000bCOMMIT;',
      'CREATE TABLE a (i int);\r\nCOMMIT;',
    ]) {
      expect(
        () => validateMigrations([Migration(version: 1, name: 'x', sql: sql)]),
        throwsA(isA<MigrationStateException>()),
        reason: sql,
      );
    }
  });
}
