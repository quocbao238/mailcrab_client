import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/api_client.dart';
import '../services/sso_session.dart';
import '../services/sso_session_webview.dart';

Future<String?> showSsoLoginDialog(
  BuildContext context, {
  required String serverUrl,
}) {
  final session = WebViewSsoSession();
  if (!session.isSupported) return Future.value(null);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SsoLoginDialog(
      serverUrl: MailCrabApi.normalizeServerUrl(serverUrl),
      session: session,
    ),
  );
}

class _SsoLoginDialog extends StatefulWidget {
  final Uri serverUrl;
  final WebViewSsoSession session;

  const _SsoLoginDialog({required this.serverUrl, required this.session});

  @override
  State<_SsoLoginDialog> createState() => _SsoLoginDialogState();
}

class _SsoLoginDialogState extends State<_SsoLoginDialog> {
  Uri? _current;
  bool _loading = true;
  bool _finishing = false;

  Future<void> _onLanded() async {
    if (_finishing) return;
    _finishing = true;
    final header = await widget.session.readCookieHeader(widget.serverUrl);
    if (!mounted) return;
    if (header.isEmpty) {
      _finishing = false;
      return;
    }
    Navigator.of(context).pop(header);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = _current?.host ?? widget.serverUrl.host;
    final onIdp = _current != null &&
        isIdentityProviderUrl(_current!, widget.serverUrl);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(onIdp ? Icons.lock_outline : Icons.public,
                      size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign in to MailCrab',
                            style: theme.textTheme.titleSmall),
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: InAppWebView(
                initialUrlRequest:
                    URLRequest(url: WebUri.uri(widget.serverUrl)),
                onLoadStart: (_, url) {
                  if (mounted) {
                    setState(() {
                      _current = url;
                      _loading = true;
                    });
                  }
                },
                onLoadStop: (_, url) async {
                  if (mounted) {
                    setState(() {
                      _current = url;
                      _loading = false;
                    });
                  }
                  if (url != null &&
                      !isIdentityProviderUrl(url, widget.serverUrl)) {
                    await _onLanded();
                  }
                },
                onReceivedError: (_, _, _) {
                  if (mounted) setState(() => _loading = false);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'This window closes by itself once sign-in completes.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
