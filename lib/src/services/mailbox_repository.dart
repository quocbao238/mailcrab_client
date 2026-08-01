import 'dart:typed_data';

import '../models/models.dart';

abstract class MailboxRepository {
  Uri get base;

  Uri get wsUri;

  Map<String, String> get authHeaders;

  Uri bodyUri(String id);

  Uri attachmentUri(String id, int index);

  Future<List<MailMessageMetadata>> fetchMessages();

  Future<MailMessage> fetchMessage(String id);

  Future<String> fetchRaw(String id);

  Future<Uint8List> fetchAttachmentBytes(String id, int index);

  Future<String> fetchVersion();

  Future<void> deleteMessage(String id);

  Future<void> deleteAll();

  void dispose();
}

typedef MailboxRepositoryFactory =
    MailboxRepository Function(String serverUrl, String authCookie);
