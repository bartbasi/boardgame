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

/// What [scanTransactionControl] found in a migration's SQL.
typedef TransactionControlScan = ({
  /// The transaction control statement that starts a statement (for
  /// example `COMMIT` or `START TRANSACTION`), or null if there is none.
  String? statement,

  /// True when the SQL ends inside a `BEGIN ATOMIC` function body, that is
  /// the body's closing END is missing (T-101 AC4).
  bool unclosedBody,
});

/// Returns the transaction control statement that starts a statement in
/// [sql] (for example `COMMIT` or `START TRANSACTION`), or null if there is
/// none. See [scanTransactionControl] for the rules.
String? findTransactionControl(String sql) =>
    scanTransactionControl(sql).statement;

/// Scans [sql] for transaction control statements and for a `BEGIN ATOMIC`
/// function body that is never closed.
///
/// A statement starts at the beginning of [sql] and after each `;`. Before
/// matching, the scanner skips `--` and (nested) `/* */` comments, and it
/// never looks inside single-quoted strings (including E'' strings with
/// backslash escapes), double-quoted identifiers, or dollar-quoted text such
/// as a PL/pgSQL function body, so `BEGIN ... END;` inside `$$ ... $$` is
/// allowed. Matching is case-insensitive.
///
/// Function body mode (T-101): inside a SQL-standard function body
/// (`BEGIN ATOMIC ... END`) a `;` does not start a new statement. The body
/// ends at an END that is the first token right after ATOMIC or right after
/// a `;` inside the body. That is PostgreSQL's grammar
/// (`BEGIN_P ATOMIC routine_body_stmt_list END_P`, where the list is
/// `stmt ';' stmt ';' ...`): no body statement starts with END, and the END
/// of a CASE expression can never stand there because a CASE holds no `;`.
/// So `CASE`, `END`, `AS end`, `AS case`, or `t.case` anywhere else in a
/// body statement do not matter (review R1-M1). The scanner enters that mode only where
/// PostgreSQL's grammar allows such a body: in a statement that starts with
/// `CREATE FUNCTION`, `CREATE PROCEDURE`, `CREATE OR REPLACE FUNCTION`, or
/// `CREATE OR REPLACE PROCEDURE`, outside any parentheses (so not in the
/// argument list or a `RETURNS TABLE (...)` column list). Anywhere else,
/// `begin atomic` is just a column name and a label (review R3-S1), and the
/// next `;` still ends the statement.
///
/// A digit run is a number token, so a `$` right after it can open a dollar
/// quote, as in PostgreSQL's lexer (review R3-G2).
///
/// This is a lexer, not a parser: an unusual statement could be refused
/// where PostgreSQL would accept it. That only fails a migration test at
/// startup, which is the safe direction. Where the scanner and PostgreSQL
/// could disagree the other way (for example two adjacent string
/// constants), PostgreSQL rejects the SQL with a syntax error; it parses the
/// whole simple query string before running any of it, so nothing runs.
TransactionControlScan scanTransactionControl(String sql) {
  final s = sql;
  var i = 0;
  // Tokens seen so far in the current statement.
  var tokenIndex = 0;
  String? firstWord;
  String? previousWord;
  // Whether the current statement is CREATE [OR REPLACE] FUNCTION or
  // PROCEDURE, the only statements with a BEGIN ATOMIC body.
  var routine = false;
  // Parenthesis depth in the current statement, outside a body.
  var parens = 0;
  // Inside a BEGIN ATOMIC ... END body.
  var inBody = false;
  // In a body, whether the next token is the first of a body statement
  // (right after ATOMIC or after a `;`), the only place its END can be.
  var bodyStatementStart = false;

  void otherToken() {
    tokenIndex++;
    previousWord = null;
    bodyStatementStart = false;
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
      if (!inBody) {
        tokenIndex = 0;
        firstWord = null;
        previousWord = null;
        routine = false;
        parens = 0;
      } else {
        otherToken();
        bodyStatementStart = true;
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
    if (c == _dollar) {
      // A `$` inside an identifier (`a$b`) or a number token never gets
      // here: both loops below consume it or stop before it, and a `$`
      // after a number starts a dollar quote in PostgreSQL too (R3-G2).
      final tag = _dollarTag.matchAsPrefix(s, i);
      if (tag != null) {
        final close = s.indexOf(tag[0]!, tag.end);
        i = close < 0 ? s.length : close + tag[0]!.length;
        otherToken();
        continue;
      }
    }
    if (_isDigit(c)) {
      // A number token: digits, `_` separators, `.`, an exponent, or a
      // 0x/0o/0b prefix. Letters right after digits are a syntax error in
      // PostgreSQL 15 and later ("trailing junk"), so taking them along is
      // harmless. A `$` is not part of a number.
      i++;
      while (i < s.length && _isNumberPart(s.codeUnitAt(i))) {
        i++;
      }
      otherToken();
      continue;
    }
    if (_isIdentifierStart(c)) {
      final start = i;
      while (i < s.length && _isIdentifierPart(s.codeUnitAt(i))) {
        i++;
      }
      final word = s.substring(start, i).toUpperCase();
      if (!inBody) {
        if (tokenIndex == 0) {
          if (_transactionControlWords.contains(word)) return _found(word);
          firstWord = word;
        } else if (tokenIndex == 1 &&
            word == 'TRANSACTION' &&
            _transactionControlBeforeTransaction.contains(firstWord)) {
          return _found('$firstWord TRANSACTION');
        } else if (firstWord == 'CREATE' &&
            _isRoutineWord(word) &&
            (tokenIndex == 1 ||
                (tokenIndex == 3 && previousWord == 'REPLACE'))) {
          routine = true;
        } else if (routine &&
            parens == 0 &&
            word == 'ATOMIC' &&
            previousWord == 'BEGIN') {
          inBody = true;
          tokenIndex++;
          previousWord = word;
          bodyStatementStart = true;
          continue;
        }
      } else if (bodyStatementStart && word == 'END') {
        inBody = false;
      }
      tokenIndex++;
      previousWord = word;
      bodyStatementStart = false;
      continue;
    }
    // An operator or punctuation.
    if (!inBody) {
      if (c == _openParen) {
        parens++;
      } else if (c == _closeParen && parens > 0) {
        parens--;
      }
    }
    i++;
    otherToken();
  }
  return (statement: null, unclosedBody: inBody);
}

TransactionControlScan _found(String statement) =>
    (statement: statement, unclosedBody: false);

/// FUNCTION or PROCEDURE after CREATE or CREATE OR REPLACE
/// (https://www.postgresql.org/docs/18/sql-createfunction.html,
/// sql-createprocedure.html: `CREATE [ OR REPLACE ] FUNCTION`).
bool _isRoutineWord(String word) => word == 'FUNCTION' || word == 'PROCEDURE';

const _minus = 0x2D;
const _slash = 0x2F;
const _star = 0x2A;
const _semicolon = 0x3B;
const _quote = 0x27;
const _doubleQuote = 0x22;
const _dollar = 0x24;
const _backslash = 0x5C;
const _lowerE = 0x65;
const _openParen = 0x28;
const _closeParen = 0x29;
const _dot = 0x2E;

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

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isIdentifierStart(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F ||
    c >= 0x80;

bool _isIdentifierPart(int c) =>
    _isIdentifierStart(c) || _isDigit(c) || c == _dollar;

/// Characters the scanner takes into a number token after its first digit.
bool _isNumberPart(int c) => _isIdentifierStart(c) || _isDigit(c) || c == _dot;

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
