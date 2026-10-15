import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// T-084 AC6 support (the AC itself is a manual schema read). Acknowledging
/// an account deletion notification is enough only while we store no eBay
/// user data (PRD section 8, EBAY-10, EBAY-18). This guards the schema
/// against the identifiers a notification names (username, userId,
/// eiasToken, EBAY-15) and seller or buyer columns, so a later migration
/// (T-055 listing cache) that adds one fails here and must come with real
/// deletion handling instead.
void main() {
  test('no migration names a seller, buyer, eBay user, or EIAS column', () {
    final forbidden = RegExp(
      r'seller|buyer|username|user_name|user_id|userid|eias',
      caseSensitive: false,
    );
    for (final migration in schemaMigrations) {
      expect(
        forbidden.allMatches(migration.sql).map((m) => m[0]).toList(),
        isEmpty,
        reason:
            'migration ${migration.version} (${migration.name}) seems to '
            'store eBay user data; T-084 handles notifications by '
            'acknowledging only',
      );
    }
  });
}
