/// Statements that end or nest the transaction a migration runs in. Each is
/// refused when it is the first word of a statement
/// (https://www.postgresql.org/docs/18/sql-commands.html): BEGIN, COMMIT
/// (also COMMIT AND CHAIN and COMMIT PREPARED), END, ROLLBACK (also
/// ROLLBACK TO and ROLLBACK PREPARED), ABORT, SAVEPOINT, and RELEASE.
const _transactionControlWords = {
  'ABORT',
  'BEGIN',
  'COMMIT',
  'END',
  'RELEASE',
  'ROLLBACK',
  'SAVEPOINT',
};

/// First words refused only when TRANSACTION follows them:
/// START TRANSACTION and PREPARE TRANSACTION. (PREPARE name AS ... is a
/// prepared statement, not transaction control.)
const _transactionControlBeforeTransaction = {'PREPARE', 'START'};

/// Returns the transaction control statement that starts a statement in
/// [sql] (for example `COMMIT` or `START TRANSACTION`), or null if there is
/// none.
///
/// A statement starts at the beginning of [sql] and after each `;`. Before
/// matching, the scanner skips `--` and (nested) `/* */` comments, and it
/// never looks inside single-quoted strings (including E'' strings with
/// backslash escapes), double-quoted identifiers, or dollar-quoted text such
/// as a PL/pgSQL function body, so `BEGIN ... END;` inside `$$ ... $$` is
/// allowed. Inside a SQL-standard function body (`BEGIN ATOMIC ... END`) a
/// `;` does not start a new statement. Matching is case-insensitive.
///
/// This is a lexer, not a parser: an unusual statement could be refused
/// where PostgreSQL would accept it. That only fails a migration test at
/// startup, which is the safe direction.
String? findTransactionControl(String sql) {
  final s = sql;
  var i = 0;
  // Tokens seen so far in the current statement.
  var tokenIndex = 0;
  String? firstWord;
  String? previousWord;
  // Depth of BEGIN ATOMIC ... END (and CASE ... END inside it).
  var atomicDepth = 0;

  void otherToken() {
    tokenIndex++;
    previousWord = null;
  }

  while (i < s.length) {
    final c = s.codeUnitAt(i);
    final next = i + 1 < s.length ? s.codeUnitAt(i + 1) : -1;

    if (c == _minus && next == _minus) {
      // PostgreSQL's lexer ends a `--` comment at LF or CR
      // (scan.l: comment ("--"{non_newline}*), newline [\n\r]).
      i += 2;
      while (i < s.length && !_isNewline(s.codeUnitAt(i))) {
        i++;
      }
      continue;
    }
    if (c == _slash && next == _star) {
      i = _skipBlockComment(s, i);
      continue;
    }
    if (_isSpace(c)) {
      i++;
      continue;
    }
    if (c == _semicolon) {
      i++;
      if (atomicDepth == 0) {
        tokenIndex = 0;
        firstWord = null;
        previousWord = null;
      } else {
        otherToken();
      }
      continue;
    }
    if (c == _quote) {
      final escapes =
          i > 0 &&
          (s.codeUnitAt(i - 1) | 0x20) == _lowerE &&
          (i < 2 || !_isIdentifierPart(s.codeUnitAt(i - 2)));
      i = _skipQuoted(s, i, _quote, backslashEscapes: escapes);
      otherToken();
      continue;
    }
    if (c == _doubleQuote) {
      i = _skipQuoted(s, i, _doubleQuote, backslashEscapes: false);
      otherToken();
      continue;
    }
    if (c == _dollar && (i == 0 || !_isIdentifierPart(s.codeUnitAt(i - 1)))) {
      final tag = _dollarTag.matchAsPrefix(s, i);
      if (tag != null) {
        final close = s.indexOf(tag[0]!, tag.end);
        i = close < 0 ? s.length : close + tag[0]!.length;
        otherToken();
        continue;
      }
    }
    if (_isIdentifierStart(c)) {
      final start = i;
      while (i < s.length && _isIdentifierPart(s.codeUnitAt(i))) {
        i++;
      }
      final word = s.substring(start, i).toUpperCase();
      if (atomicDepth == 0) {
        if (tokenIndex == 0) {
          if (_transactionControlWords.contains(word)) return word;
          firstWord = word;
        } else if (tokenIndex == 1 &&
            word == 'TRANSACTION' &&
            _transactionControlBeforeTransaction.contains(firstWord)) {
          return '$firstWord TRANSACTION';
        } else if (word == 'ATOMIC' && previousWord == 'BEGIN') {
          atomicDepth = 1;
        }
      } else if (word == 'CASE') {
        atomicDepth++;
      } else if (word == 'END') {
        atomicDepth--;
      }
      tokenIndex++;
      previousWord = word;
      continue;
    }
    // A number, operator, or punctuation.
    i++;
    otherToken();
  }
  return null;
}

const _minus = 0x2D;
const _slash = 0x2F;
const _star = 0x2A;
const _semicolon = 0x3B;
const _quote = 0x27;
const _doubleQuote = 0x22;
const _dollar = 0x24;
const _backslash = 0x5C;
const _lowerE = 0x65;

/// `$$` or `$tag$` (https://www.postgresql.org/docs/18/sql-syntax-lexical.html,
/// 4.1.2.4): the tag follows the rules of an unquoted identifier but may not
/// contain a dollar sign.
final _dollarTag = RegExp(r'\$(?:[A-Za-z_\u0080-￿][A-Za-z0-9_\u0080-￿]*)?\$');

/// PostgreSQL's lexer whitespace, exactly: `space [ \t\n\r\f\v]` in
/// src/backend/parser/scan.l (REL_18_STABLE, checked 2026-10-14): space,
/// tab, line feed, carriage return, form feed, and vertical tab.
bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0C || c == 0x0B;

/// `newline [\n\r]` in scan.l.
bool _isNewline(int c) => c == 0x0A || c == 0x0D;

bool _isIdentifierStart(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F ||
    c >= 0x80;

bool _isIdentifierPart(int c) =>
    _isIdentifierStart(c) || (c >= 0x30 && c <= 0x39) || c == _dollar;

/// Returns the index after the block comment starting at [start]. PostgreSQL
/// block comments nest.
int _skipBlockComment(String s, int start) {
  var depth = 0;
  var i = start;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    final next = i + 1 < s.length ? s.codeUnitAt(i + 1) : -1;
    if (c == _slash && next == _star) {
      depth++;
      i += 2;
    } else if (c == _star && next == _slash) {
      depth--;
      i += 2;
      if (depth == 0) return i;
    } else {
      i++;
    }
  }
  return s.length;
}

/// Returns the index after the quoted text starting at [start]. A doubled
/// [quote] stands for itself; with [backslashEscapes] a backslash escapes
/// the next character.
int _skipQuoted(
  String s,
  int start,
  int quote, {
  required bool backslashEscapes,
}) {
  var i = start + 1;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (backslashEscapes && c == _backslash) {
      i += 2;
    } else if (c == quote) {
      if (i + 1 < s.length && s.codeUnitAt(i + 1) == quote) {
        i += 2;
      } else {
        return i + 1;
      }
    } else {
      i++;
    }
  }
  return s.length;
}
