import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'sso_session.dart';

class WebViewSsoSession implements SsoSessionProvider {
  static const renewTimeout = Duration(seconds: 20);

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS ||
          Platform.isIOS ||
          Platform.isAndroid ||
          Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  Future<String> readCookieHeader(Uri serverUrl) async {
    if (!isSupported) return '';
    try {
      final cookies = await CookieManager.instance()
          .getCookies(url: WebUri.uri(serverUrl));
      return buildCookieHeader(
        cookies.map((c) => (name: c.name, value: '${c.value}')),
      );
    } catch (e) {
      debugPrint('SSO: could not read cookies: $e');
      return '';
    }
  }

  @override
  Future<String?> renew(Uri serverUrl) async {
    if (!isSupported) return null;

    final probe = serverUrl.replace(
      path: '${serverUrl.path}/api/version',
    );
    final done = Completer<void>();
    HeadlessInAppWebView? webView;
    var landed = false;

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(probe)),
        initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
        onLoadStop: (controller, url) async {
          if (url == null || !isIdentityProviderUrl(url, serverUrl)) {
            landed = true;
            finish();
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('SSO renew: load error ${error.description}');
          finish();
        },
      );
      await webView.run();
      await done.future.timeout(renewTimeout, onTimeout: () {
        debugPrint('SSO renew: timed out — interactive sign-in needed');
      });

      if (!landed) return null;
      final header = await readCookieHeader(serverUrl);
      return header.isEmpty ? null : header;
    } catch (e) {
      debugPrint('SSO renew: failed: $e');
      return null;
    } finally {
      await webView?.dispose();
    }
  }

  Future<void> signOut() async {
    if (!isSupported) return;
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      debugPrint('SSO: could not clear cookies: $e');
    }
  }
}
