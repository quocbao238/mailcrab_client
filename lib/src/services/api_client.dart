import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class MailCrabApiException implements Exception {
  final String message;
  MailCrabApiException(this.message);

  @override
  String toString() => message;
}

class MailCrabAuthException extends MailCrabApiException {
  final bool hadCookie;

  MailCrabAuthException({required this.hadCookie})
      : super(hadCookie
            ? 'Session expired — the auth cookie was rejected. Sign in '
                'again in your browser and paste the new cookie in Settings.'
            : 'This server is behind an SSO sign-in. Sign in with your '
                'browser and paste the session cookie in Settings.');
}

class MailCrabApi {
  final Uri base;

  final Map<String, String> authHeaders;
  final http.Client _client;

  MailCrabApi(String serverUrl, {String authCookie = '', http.Client? client})
      : base = normalizeServerUrl(serverUrl),
        authHeaders = authCookie.trim().isEmpty
            ? const {}
            : {'Cookie': authCookie.trim()},
        _client = client ?? http.Client();

  static Uri normalizeServerUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) raw = 'http://localhost:1080';
    if (!raw.contains('://')) raw = 'http://$raw';
    var uri = Uri.parse(raw);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      uri = uri.replace(scheme: 'http');
    }
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  Uri _endpoint(String path) => base.replace(path: '${base.path}$path');

  Uri get wsUri => _endpoint('/ws')
      .replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');

  Uri bodyUri(String id) => _endpoint('/api/message/$id/body');

  Uri attachmentUri(String id, int index) =>
      _endpoint('/api/message/$id/attachment/$index');

  Future<List<MailMessageMetadata>> fetchMessages() async {
    final res = await _get('/api/messages');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(MailMessageMetadata.fromJson)
        .toList();
  }

  Future<MailMessage> fetchMessage(String id) async {
    final res = await _get('/api/message/$id');
    return MailMessage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> fetchRaw(String id) async {
    final res = await _get('/api/message/$id/raw');
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  Future<Uint8List> fetchAttachmentBytes(String id, int index) async {
    final res = await _get('/api/message/$id/attachment/$index');
    return res.bodyBytes;
  }

  Future<String> fetchVersion() async {
    final res = await _get('/api/version');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['version_be']?.toString() ?? 'unknown';
  }

  Future<void> deleteMessage(String id) => _post('/api/delete/$id');

  Future<void> deleteAll() => _post('/api/delete-all');

  Future<http.Response> _get(String path) => _send('GET', path);

  Future<http.Response> _post(String path) => _send('POST', path);

  Future<http.Response> _send(String method, String path) async {
    final request = http.Request(method, _endpoint(path))
      ..followRedirects = false
      ..headers.addAll(authHeaders);
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 10));
    final res = await http.Response.fromStream(streamed);
    _check(res, path);
    return res;
  }

  void _check(http.Response res, String path) {
    if ((res.statusCode >= 300 && res.statusCode < 400) ||
        res.statusCode == 401 ||
        res.statusCode == 403) {
      throw MailCrabAuthException(hadCookie: authHeaders.isNotEmpty);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MailCrabApiException(
          'MailCrab returned HTTP ${res.statusCode} for $path');
    }
  }

  void dispose() => _client.close();
}
