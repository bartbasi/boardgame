/// Shared T-101 AC2 cases, used by the unit test
/// (test/db/transaction_control_test.dart) and by the PostgreSQL check
/// (test/db/transaction_control_postgres_test.dart).
library;

/// `begin atomic` as a column and a label in a SELECT list, for T-101 AC2.
const _beginAtomicSelect = 'SELECT begin atomic FROM (SELECT 1 AS begin) s';

/// Statements that contain the words `begin atomic` but are not
/// CREATE [OR REPLACE] FUNCTION or PROCEDURE, or hold them inside
/// parentheses where no body can start (T-101 AC2). Each is valid
/// PostgreSQL 18 (test/db/transaction_control_postgres_test.dart runs them
/// all) and is followed by `; ROLLBACK;` in the test.
const beginAtomicOutsideABody = {
  'SELECT': _beginAtomicSelect,
  'INSERT': 'INSERT INTO t101_t (begin) $_beginAtomicSelect',
  'UPDATE': 'UPDATE t101_t SET begin = s.atomic FROM ($_beginAtomicSelect) s',
  'CREATE TABLE AS': 'CREATE TABLE t101_ctas AS $_beginAtomicSelect',
  'CREATE VIEW': 'CREATE VIEW t101_v AS $_beginAtomicSelect',
  'CREATE OR REPLACE VIEW':
      'CREATE OR REPLACE VIEW t101_v2 AS $_beginAtomicSelect',
  'CREATE MATERIALIZED VIEW':
      'CREATE MATERIALIZED VIEW t101_mv AS $_beginAtomicSelect',
  'WITH ... SELECT': 'WITH w AS ($_beginAtomicSelect) SELECT atomic FROM w',
  'a CREATE FUNCTION argument named begin of type atomic':
      'CREATE FUNCTION t101_f(begin atomic) RETURNS int LANGUAGE sql '
      "AS 'SELECT 1'",
  'a CREATE FUNCTION RETURNS TABLE column named begin of type atomic':
      'CREATE FUNCTION t101_g() RETURNS TABLE (begin atomic) LANGUAGE sql '
      "AS 'SELECT 1'",
  'a CREATE TRIGGER that executes a function':
      'CREATE TRIGGER t101_trg BEFORE INSERT ON t101_t FOR EACH ROW '
      'EXECUTE FUNCTION t101_trigger_fn()',
  'a CREATE TABLE with columns named begin and atomic':
      'CREATE TABLE t101_cols (begin int, atomic int)',
};

/// Setup that makes [beginAtomicOutsideABody] valid on real PostgreSQL.
const beginAtomicOutsideABodySetup = r'''
CREATE TABLE t101_t (begin int);
CREATE DOMAIN atomic AS int;
CREATE FUNCTION t101_trigger_fn() RETURNS trigger LANGUAGE plpgsql
  AS $$ BEGIN RETURN NEW; END; $$;
''';
