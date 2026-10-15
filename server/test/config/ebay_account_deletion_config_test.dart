import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

const _token = 'fake-token-fake-token-fake-token-fake-token';
const _url = 'https://api.example.com/ebay/marketplace-account-deletion';

Map<String, String> _env({String? token = _token, String? url = _url}) => {
  ebayAccountDeletionTokenVariable: ?token,
  ebayAccountDeletionUrlVariable: ?url,
};

/// The single problem [EbayAccountDeletionConfig.load] reports for [env].
String _problem(Map<String, String> env) {
  try {
    EbayAccountDeletionConfig.load(env);
  } on ConfigException catch (e) {
    return e.problems.single;
  }
  fail('expected a ConfigException');
}

void main() {
  group('both or neither (T-084)', () {
    test('neither set: the endpoint is off', () {
      expect(EbayAccountDeletionConfig.load({}), isNull);
      expect(EbayAccountDeletionConfig.load(_env(token: '', url: ' ')), isNull);
    });

    test('both valid: loaded, URL kept as written apart from surrounding '
        'whitespace', () {
      final config = EbayAccountDeletionConfig.load(
        _env(token: ' $_token ', url: '\t$_url '),
      )!;
      expect(config.verificationToken, _token);
      expect(config.endpointUrl, _url);
    });

    test('only one set is an error naming the missing variable', () {
      expect(
        _problem(_env(token: null)),
        startsWith('$ebayAccountDeletionTokenVariable is missing'),
      );
      expect(
        _problem(_env(url: null)),
        startsWith('$ebayAccountDeletionUrlVariable is missing'),
      );
    });

    test('both invalid: both problems in one exception', () {
      expect(
        () => EbayAccountDeletionConfig.load(
          _env(token: 'short', url: 'http://localhost/'),
        ),
        throwsA(
          isA<ConfigException>().having((e) => e.problems, 'problems', [
            startsWith('$ebayAccountDeletionTokenVariable is invalid'),
            startsWith('$ebayAccountDeletionUrlVariable is invalid'),
          ]),
        ),
      );
    });

    test('toString never prints the token', () {
      final config = EbayAccountDeletionConfig.load(_env())!;
      expect(config.toString(), isNot(contains(_token)));
    });
  });

  group('AC3: verification token is 32 to 80 letters, digits, underscore, '
      'or hyphen', () {
    final valid = <String, String>{
      '32 characters (minimum)': 'a' * 32,
      '80 characters (maximum)': 'Z' * 80,
      'letters, digits, underscore, hyphen': 'Ab0_-' * 8,
      'all digits': '1' * 40,
    };
    final invalid = <String, String>{
      '31 characters': 'a' * 31,
      '81 characters': 'a' * 81,
      'a space inside': '${'a' * 20} ${'a' * 20}',
      'a dot': '${'a' * 32}.',
      'a plus sign': '${'a' * 32}+',
      'a slash': '${'a' * 32}/',
      'an equals sign (Base64 padding)': '${'a' * 32}=',
      'a non-ASCII letter': '${'a' * 32}é',
      'a non-ASCII digit': '${'a' * 32}١',
      'a newline inside': '${'a' * 20}\n${'a' * 20}',
    };

    for (final MapEntry(key: name, value: token) in valid.entries) {
      test('accepts $name', () {
        expect(isValidVerificationToken(token), isTrue);
        expect(
          EbayAccountDeletionConfig.load(_env(token: token))!.verificationToken,
          token,
        );
      });
    }

    for (final MapEntry(key: name, value: token) in invalid.entries) {
      test('startup config fails for $name, without printing the value', () {
        expect(isValidVerificationToken(token), isFalse);
        final problem = _problem(_env(token: token));
        expect(
          problem,
          '$ebayAccountDeletionTokenVariable is invalid; it must be 32 to 80 '
          'letters, digits, underscores, or hyphens.',
        );
        expect(problem, isNot(contains('aaaa')));
      });
    }
  });

  group('AC4: endpoint URL must be https and not localhost or an internal '
      'IP address', () {
    const path = '/ebay/marketplace-account-deletion';
    final valid = [
      'https://api.example.com$path',
      'https://api.example.com:8443$path',
      'https://deep.sub.example.co.uk$path',
      'https://xn--bcher-kva.example$path',
      'https://8.8.8.8$path',
      'https://[2606:4700:4700::1111]$path',
    ];
    final invalid = <String, String>{
      'http': 'http://api.example.com$path',
      'no scheme': 'api.example.com$path',
      'ftp': 'ftp://api.example.com$path',
      'wss': 'wss://api.example.com$path',
      'localhost': 'https://localhost$path',
      'LOCALHOST': 'https://LOCALHOST$path',
      'a .localhost name': 'https://api.localhost$path',
      'a single-label host': 'https://server$path',
      'a numeric last label (127.1)': 'https://127.1$path',
      'a hex last label': 'https://0x7f.1$path',
      'a decimal IP form': 'https://2130706433$path',
      'a trailing-dot IP': 'https://10.0.0.1.$path',
      'IPv4 loopback': 'https://127.0.0.1$path',
      'IPv4 loopback, other address': 'https://127.8.9.10$path',
      'unspecified 0.0.0.0': 'https://0.0.0.0$path',
      '10.0.0.0/8': 'https://10.1.2.3$path',
      '172.16.0.0/12 low': 'https://172.16.0.1$path',
      '172.16.0.0/12 high': 'https://172.31.255.254$path',
      '192.168.0.0/16': 'https://192.168.1.10$path',
      '169.254.0.0/16 link-local': 'https://169.254.169.254$path',
      '100.64.0.0/10 shared': 'https://100.64.0.1$path',
      '192.0.2.0/24 documentation': 'https://192.0.2.1$path',
      '198.18.0.0/15 benchmarking': 'https://198.19.0.1$path',
      'multicast': 'https://224.0.0.1$path',
      'reserved 240/4': 'https://250.1.1.1$path',
      'Caddy\'s Compose address': 'https://10.213.7.10$path',
      'IPv6 loopback': 'https://[::1]$path',
      'IPv6 unspecified': 'https://[::]$path',
      'IPv6 unique local': 'https://[fd00::1]$path',
      'IPv6 link-local': 'https://[fe80::1]$path',
      'IPv6 documentation': 'https://[2001:db8::1]$path',
      'IPv4-mapped loopback': 'https://[::ffff:127.0.0.1]$path',
      'IPv4-mapped private': 'https://[::ffff:10.0.0.1]$path',
      'user info': 'https://user:pw@api.example.com$path',
      'a query': 'https://api.example.com$path?x=1',
      'a fragment': 'https://api.example.com$path#x',
      'another path': 'https://api.example.com/notify',
      'a trailing slash': 'https://api.example.com$path/',
      'no path': 'https://api.example.com',
      'unparseable': 'https://[::1$path',
      'too long': 'https://${'a' * 2040}.example.com$path',
    };

    for (final url in valid) {
      test('accepts $url', () {
        expect(endpointUrlProblem(url), isNull);
        expect(
          EbayAccountDeletionConfig.load(_env(url: url))!.endpointUrl,
          url,
        );
      });
    }

    for (final MapEntry(key: name, value: url) in invalid.entries) {
      test('startup config fails for $name, without printing the URL', () {
        final reason = endpointUrlProblem(url);
        expect(reason, isNotNull);
        final problem = _problem(_env(url: url));
        expect(
          problem,
          startsWith('$ebayAccountDeletionUrlVariable is invalid; '),
        );
        expect(problem, isNot(contains('example.com')));
        expect(problem, isNot(contains('127.')));
      });
    }

    test('R1-G1: spellings that only mean the same URL are refused, so the '
        'hashed string is exactly what eBay calls', () {
      for (final url in [
        'https://API.Example.COM$path',
        'https://api.EXAMPLE.com$path',
        'HTTPS://api.example.com$path',
        'Https://api.example.com$path',
        'https://@api.example.com$path',
        'https://api.example.com/ebay/./marketplace-account-deletion',
        'https://api.example.com/x/../ebay/marketplace-account-deletion',
        'https://api.example.com/ebay/marketplace%2Daccount-deletion',
        'https://api.example.com:$path',
        'https://ex%61mple.com$path',
      ]) {
        expect(
          endpointUrlProblem(url),
          startsWith('it must be written in canonical form'),
          reason: url,
        );
        expect(_problem(_env(url: url)), isNot(contains('xample')));
      }
    });

    test('R1-G1: canonical forms with a port, an IPv6 literal, and an IDN '
        'A-label still pass', () {
      for (final url in [
        'https://api.example.com:8443$path',
        'https://[2606:4700:4700::1111]$path',
        'https://xn--bcher-kva.example$path',
      ]) {
        expect(Uri.parse(url).toString(), url);
        expect(endpointUrlProblem(url), isNull, reason: url);
      }
    });

    test('the path rule names our route', () {
      expect(endpointUrlProblem('https://api.example.com/x'), contains(path));
      expect(ebayAccountDeletionPath, path);
    });
  });

  group('isPublicAddress', () {
    test('public unicast passes; IPv6 outside 2000::/3 does not', () {
      expect(isPublicAddress(InternetAddress('1.1.1.1')), isTrue);
      expect(isPublicAddress(InternetAddress('172.32.0.1')), isTrue);
      expect(isPublicAddress(InternetAddress('100.128.0.1')), isTrue);
      expect(isPublicAddress(InternetAddress('::ffff:8.8.8.8')), isTrue);
      expect(isPublicAddress(InternetAddress('2a01:4f8::1')), isTrue);
      expect(isPublicAddress(InternetAddress('ff02::1')), isFalse);
      expect(isPublicAddress(InternetAddress('64:ff9b::1')), isFalse);
    });
  });
}
