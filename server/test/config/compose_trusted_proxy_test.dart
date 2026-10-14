import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// T-020 AC4: the address the server trusts for X-Forwarded-For is Caddy's
/// fixed address on the Compose `web` network, and the two stay in sync.
void main() {
  // `dart test` runs in server/; the Linux test container copies only
  // server/ and packages/, so the file may be missing there.
  final compose = File('../deploy/docker-compose.yml');

  test('deploy/docker-compose.yml pins Caddy to the address the server '
      'trusts, inside the web subnet', () {
    if (!compose.existsSync()) {
      markTestSkipped('deploy/docker-compose.yml is not in this checkout');
      return;
    }
    final text = compose.readAsStringSync();

    final trusted = RegExp(
      r'^\s+TRUSTED_PROXY_ADDRESSES:\s*"([^"]+)"\s*$',
      multiLine: true,
    ).allMatches(text).toList();
    final caddyAddress = RegExp(
      r'^\s+ipv4_address:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(text).toList();
    final subnet = RegExp(
      r'^\s+- subnet:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(text).toList();

    expect(trusted, hasLength(1));
    expect(caddyAddress, hasLength(1));
    expect(subnet, hasLength(1));

    final config = Config.load({
      'PORT': '8080',
      'LOG_LEVEL': 'info',
      'TRUSTED_PROXY_ADDRESSES': trusted.single[1]!,
    });
    expect(config.trustedProxies, [InternetAddress(caddyAddress.single[1]!)]);

    // The address lies inside the subnet (a /24 here).
    final cidr = subnet.single[1]!.split('/');
    expect(cidr[1], '24');
    final network = InternetAddress(cidr[0]).rawAddress;
    final caddy = InternetAddress(caddyAddress.single[1]!).rawAddress;
    expect(caddy.sublist(0, 3), network.sublist(0, 3));
    expect(caddy[3], inInclusiveRange(2, 254), reason: '.1 is the gateway');

    // The ipv4_address belongs to the caddy service.
    final caddyService = text.indexOf('\n  caddy:');
    expect(caddyService, greaterThan(0));
    expect(caddyAddress.single.start, greaterThan(caddyService));
  });
}
