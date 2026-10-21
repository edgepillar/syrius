/// Who is asking, taken from the `Origin` header of a WebSocket upgrade.
///
/// Returns the origin in its canonical form (`scheme://host[:port]`), or null
/// when it may not talk to the wallet. https is accepted from anywhere. http
/// is accepted only from a private host, because on the open internet anyone
/// on the path could have written the page. The rule is the Syrius Android
/// app's rule for callbacks, so one origin means the same thing in both.
String? dappBridgeRequester(String? origin) {
  if (origin == null || origin.isEmpty || origin.length > 2048) {
    return null;
  }
  final Uri? uri = Uri.tryParse(origin);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
  // An origin has no path, query or fragment. A header that carries one did
  // not come from a browser.
  if ((uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final String host = uri.host.toLowerCase();
  if (uri.scheme == 'http') {
    if (!isPrivateHost(host)) {
      return null;
    }
  } else if (uri.scheme != 'https') {
    return null;
  }
  final String port = uri.hasPort && uri.port != _defaultPort(uri.scheme)
      ? ':${uri.port}'
      : '';
  final String shownHost = host.contains(':') ? '[$host]' : host;
  return '${uri.scheme}://$shownHost$port';
}

/// What a requester that came by `syrius://request` is stored and shown
/// under: this prefix, then the origin of its callback.
///
/// A link names its own callback, so unlike a socket's `Origin` nothing
/// proves who wrote it. Keeping the two apart means a link that names a site
/// the person connected over the socket does not inherit that consent, and
/// the approval can say the sender is not verified. No `Origin` header can
/// produce a requester with this prefix: [dappBridgeRequester] only returns
/// `http://` and `https://`.
const String kDappBridgeLinkPrefix = 'link:';

/// The requester for a `syrius://request` whose answer goes to [callback],
/// or null when the wallet will not open that callback.
///
/// Only what the socket accepts as an origin is accepted here. The Android
/// app also takes another app's own scheme; on a desktop that would let a
/// web page have the wallet launch any registered scheme handler without the
/// browser's own prompt.
String? dappBridgeLinkRequester(Uri callback) {
  if (!callback.hasScheme || callback.host.isEmpty) {
    return null;
  }
  final String? origin = dappBridgeRequester(
    Uri(
      scheme: callback.scheme,
      userInfo: callback.userInfo,
      host: callback.host,
      port: callback.hasPort ? callback.port : null,
    ).toString(),
  );
  return origin == null ? null : '$kDappBridgeLinkPrefix$origin';
}

/// Whether [requester] came by link rather than over the socket.
bool dappBridgeIsLink(String requester) =>
    requester.startsWith(kDappBridgeLinkPrefix);

/// The origin to show for [requester], without the link prefix.
String dappBridgeShownOrigin(String requester) => dappBridgeIsLink(requester)
    ? requester.substring(kDappBridgeLinkPrefix.length)
    : requester;

/// Whether the `Host` header names this machine's loopback on [port].
///
/// A page served from a public name that later resolves to 127.0.0.1 (DNS
/// rebinding) still sends its public name here, and is refused.
bool isLoopbackHostHeader(String? hostHeader, int port) {
  if (hostHeader == null) {
    return false;
  }
  final String value = hostHeader.toLowerCase();
  return value == '127.0.0.1:$port' ||
      value == 'localhost:$port' ||
      value == '[::1]:$port';
}

/// `localhost`, `*.localhost`, `*.local`, `::1`, 127/8, 10/8, 172.16/12 and
/// 192.168/16.
bool isPrivateHost(String host) {
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host == '::1') {
    return true;
  }
  final List<String> parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }
  final List<int> octets = <int>[];
  for (final String part in parts) {
    final int? octet = part.length <= 3 ? int.tryParse(part) : null;
    if (octet == null || octet < 0 || octet > 255) {
      return false;
    }
    octets.add(octet);
  }
  return octets[0] == 127 ||
      octets[0] == 10 ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168);
}

int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;
