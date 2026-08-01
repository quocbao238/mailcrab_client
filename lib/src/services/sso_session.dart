library;

typedef CookiePair = ({String name, String value});

String buildCookieHeader(Iterable<CookiePair> cookies) {
  final parts = <String>[];
  final seen = <String>{};
  for (final c in cookies) {
    final name = c.name.trim();
    if (name.isEmpty || !seen.add(name)) continue;
    parts.add('$name=${c.value}');
  }
  return parts.join('; ');
}

bool isIdentityProviderUrl(Uri url, Uri serverUrl) =>
    url.host.isNotEmpty && url.host != serverUrl.host;

abstract class SsoSessionProvider {
  bool get isSupported;

  Future<String?> renew(Uri serverUrl);
}

class NoSsoSession implements SsoSessionProvider {
  const NoSsoSession();

  @override
  bool get isSupported => false;

  @override
  Future<String?> renew(Uri serverUrl) async => null;
}
