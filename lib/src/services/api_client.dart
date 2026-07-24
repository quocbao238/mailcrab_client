import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class MailCrabApiException implements Exception {
  final String message;
  MailCrabApiException(this.message);

  @override
  String toString() => message;
}

class MailCrabApi {
  /// Normalized base URI without a trailing slash, may contain a path prefix.
  final Uri base;
  final http.Client _client;

  MailCrabApi(String serverUrl, {http.Client? client})
      : base = normalizeServerUrl(serverUrl),
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

  /// WebSocket endpoint derived from the base URL.
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

  Future<String> fetchVersion() async {
    final res = await _get('/api/version');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['version_be']?.toString() ?? 'unknown';
  }

  Future<void> deleteMessage(String id) => _post('/api/delete/$id');

  Future<void> deleteAll() => _post('/api/delete-all');

  Future<http.Response> _get(String path) async {
    final res = await _client
        .get(_endpoint(path))
        .timeout(const Duration(seconds: 10));
    _check(res, path);
    return res;
  }

  Future<http.Response> _post(String path) async {
    final res = await _client
        .post(_endpoint(path))
        .timeout(const Duration(seconds: 10));
    _check(res, path);
    return res;
  }

  void _check(http.Response res, String path) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MailCrabApiException(
          'MailCrab returned HTTP ${res.statusCode} for $path');
    }
  }

  void dispose() => _client.close();
}
