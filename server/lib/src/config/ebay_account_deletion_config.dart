import 'dart:io';

import 'config.dart';

/// Path of the eBay marketplace account deletion endpoint on our server
/// (T-084). The configured endpoint URL must use exactly this path, so the
/// URL eBay calls and the URL hashed into the challenge response are the
/// same.
const ebayAccountDeletionPath = '$ebayMountPath$ebayAccountDeletionRoute';

/// Where the eBay routes are mounted on the root router, behind their own
/// rate limiter and outside /v1 (no app attestation, T-084 AC5).
const ebayMountPath = '/ebay';

/// The account deletion route, relative to [ebayMountPath].
const ebayAccountDeletionRoute = '/marketplace-account-deletion';

/// Variable holding the verification token entered in the eBay developer
/// portal (EBAY-11). A secret: never logged or printed.
const ebayAccountDeletionTokenVariable =
    'EBAY_ACCOUNT_DELETION_VERIFICATION_TOKEN';

/// Variable holding the endpoint URL entered in the eBay developer portal,
/// character for character (EBAY-11, EBAY-17).
const ebayAccountDeletionUrlVariable = 'EBAY_ACCOUNT_DELETION_ENDPOINT_URL';

/// Longest endpoint URL accepted [ASSUMPTION]. eBay publishes no limit;
/// ours is far above any real value.
const maxEbayEndpointUrlLength = 2048;

/// Settings of the eBay marketplace account deletion endpoint (T-084).
///
/// Both variables are optional together: with neither set, the endpoint is
/// off and its path answers 404. Setting only one is a config error. eBay
/// requires the endpoint before the first production eBay API call
/// (EBAY-10), and no eBay client exists yet, so making it required now would
/// only force placeholder values onto every local run (proposed decision in
/// docs/handoffs/T-084.md).
final class EbayAccountDeletionConfig {
  /// Creates a config. Use [load] in production code.
  const EbayAccountDeletionConfig({
    required this.verificationToken,
    required this.endpointUrl,
  });

  /// The verification token (32 to 80 letters, digits, `_`, `-`; EBAY-11).
  final String verificationToken;

  /// The endpoint URL exactly as entered in the eBay portal (only
  /// surrounding whitespace removed). Hashed as is (EBAY-13).
  final String endpointUrl;

  /// Never prints the token.
  @override
  String toString() => 'EbayAccountDeletionConfig(<redacted>)';

  /// Reads both variables from [environment]. Returns null when neither is
  /// set (endpoint off). Throws [ConfigException] naming each problem, never
  /// a value.
  static EbayAccountDeletionConfig? load(Map<String, String> environment) {
    final token = environment[ebayAccountDeletionTokenVariable]?.trim() ?? '';
    final url = environment[ebayAccountDeletionUrlVariable]?.trim() ?? '';
    if (token.isEmpty && url.isEmpty) return null;

    final problems = <String>[];
    const both =
        'set both $ebayAccountDeletionTokenVariable and '
        '$ebayAccountDeletionUrlVariable, or neither';
    if (token.isEmpty) {
      problems.add('$ebayAccountDeletionTokenVariable is missing; $both.');
    } else if (!isValidVerificationToken(token)) {
      problems.add(
        '$ebayAccountDeletionTokenVariable is invalid; it must be 32 to 80 '
        'letters, digits, underscores, or hyphens.',
      );
    }
    if (url.isEmpty) {
      problems.add('$ebayAccountDeletionUrlVariable is missing; $both.');
    } else {
      final problem = endpointUrlProblem(url);
      if (problem != null) {
        problems.add('$ebayAccountDeletionUrlVariable is invalid; $problem.');
      }
    }
    if (problems.isNotEmpty) throw ConfigException(problems);
    return EbayAccountDeletionConfig(
      verificationToken: token,
      endpointUrl: url,
    );
  }
}

final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{32,80}$');

/// Whether [token] meets eBay's rule: 32 to 80 characters, each a letter,
/// digit, underscore, or hyphen (EBAY-11).
bool isValidVerificationToken(String token) => _tokenPattern.hasMatch(token);

// A top-level domain made of letters, or an IDN A-label. Rejects numeric
// last labels, so forms such as `127.1` or `0x7f.1` that some resolvers read
// as IP addresses never pass as host names.
final _topLevelDomain = RegExp(r'^([a-z]{2,63}|xn--[a-z0-9-]{1,59})$');
final _hostLabel = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

/// Why [url] cannot be the eBay endpoint URL, or null if it can (EBAY-11:
/// https, no localhost, no internal IP address). The reason never contains
/// the URL or any part of it.
///
/// Rules:
/// - at most [maxEbayEndpointUrlLength] characters, and parses as a URL;
/// - scheme `https`;
/// - no user info, query, or fragment;
/// - path exactly [ebayAccountDeletionPath];
/// - host is a public DNS name (at least two labels, a letter-only top-level
///   label, not `localhost` or under `.localhost`), or a public IP literal
///   (see [isPublicAddress]);
/// - written in canonical form: `Uri.parse(url).toString()` gives back the
///   same string. The configured string is hashed as written (EBAY-13,
///   EBAY-17), so spellings that only mean the same URL (upper-case scheme or
///   host, dot segments, empty user info or port, needless percent escapes)
///   are refused rather than hashed differently from what eBay calls
///   (T-084 review R1-G1).
///
/// No DNS lookup is made: a public name that resolves to a private address
/// cannot be detected here, and eBay's own verification fails for it.
String? endpointUrlProblem(String url) {
  if (url.length > maxEbayEndpointUrlLength) {
    return 'it must be at most $maxEbayEndpointUrlLength characters';
  }
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return 'it is not a valid URL';
  }
  final problem = _shapeProblem(uri);
  if (problem != null) return problem;
  if (uri.toString() != url) {
    return 'it must be written in canonical form (lower-case scheme and '
        'host, no dot segments, no empty user info or port, no needless '
        'percent escapes)';
  }
  return null;
}

String? _shapeProblem(Uri uri) {
  if (uri.scheme != 'https') return 'it must start with https://';
  if (uri.userInfo.isNotEmpty) return 'it must not contain user info';
  if (uri.hasQuery) return 'it must not contain a query';
  if (uri.hasFragment) return 'it must not contain a fragment';
  if (uri.path != ebayAccountDeletionPath) {
    return 'its path must be $ebayAccountDeletionPath';
  }
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return 'it must name a host';
  final address = InternetAddress.tryParse(host);
  if (address != null) {
    return isPublicAddress(address)
        ? null
        : 'its host must not be a loopback, private, or other internal '
              'IP address';
  }
  if (host == 'localhost' || host.endsWith('.localhost')) {
    return 'its host must not be localhost';
  }
  final labels = host.split('.');
  if (labels.length < 2 ||
      !labels.every(_hostLabel.hasMatch) ||
      !_topLevelDomain.hasMatch(labels.last)) {
    return 'its host must be a public domain name (two or more labels, a '
        'letter-only top-level label)';
  }
  return null;
}

/// Whether [address] is a public unicast address, that is, not loopback,
/// private, link-local, shared (CGNAT), documentation, benchmarking,
/// multicast, reserved, or unspecified. IPv4-mapped IPv6 is judged as its
/// IPv4 address; other IPv6 must be global unicast (2000::/3) outside the
/// documentation range 2001:db8::/32.
bool isPublicAddress(InternetAddress address) {
  final raw = address.rawAddress;
  if (raw.length == 4) return _isPublicIPv4(raw);
  final mapped =
      raw.sublist(0, 10).every((b) => b == 0) &&
      raw[10] == 0xff &&
      raw[11] == 0xff;
  if (mapped) return _isPublicIPv4(raw.sublist(12));
  if ((raw[0] & 0xe0) != 0x20) return false;
  if (raw[0] == 0x20 && raw[1] == 0x01 && raw[2] == 0x0d && raw[3] == 0xb8) {
    return false;
  }
  return true;
}

bool _isPublicIPv4(List<int> b) {
  final a = b[0];
  return !(a == 0 ||
      a == 10 ||
      a == 127 ||
      a >= 224 ||
      (a == 100 && b[1] >= 64 && b[1] <= 127) ||
      (a == 169 && b[1] == 254) ||
      (a == 172 && b[1] >= 16 && b[1] <= 31) ||
      (a == 192 && b[1] == 0 && b[2] == 0) ||
      (a == 192 && b[1] == 0 && b[2] == 2) ||
      (a == 192 && b[1] == 168) ||
      (a == 198 && (b[1] == 18 || b[1] == 19)) ||
      (a == 198 && b[1] == 51 && b[2] == 100) ||
      (a == 203 && b[1] == 0 && b[2] == 113));
}
