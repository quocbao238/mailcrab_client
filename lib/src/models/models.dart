/// Data models mirroring MailCrab's JSON API types
/// (see backend `MailMessage` / `MailMessageMetadata`).
library;

import 'package:equatable/equatable.dart';

class Address extends Equatable {
  final String? name;
  final String? email;

  const Address({this.name, this.email});

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        name: json['name'] as String?,
        email: json['email'] as String?,
      );

  /// Human readable form: `Name <email>`, or whichever part is present.
  String get display {
    final n = name?.trim() ?? '';
    final e = email?.trim() ?? '';
    if (n.isNotEmpty && e.isNotEmpty) return '$n <$e>';
    if (n.isNotEmpty) return n;
    if (e.isNotEmpty) return e;
    return '(unknown)';
  }

  /// Short form for list tiles: prefer the display name.
  String get short {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final e = email?.trim() ?? '';
    if (e.isNotEmpty) return e;
    return '(unknown)';
  }

  @override
  List<Object?> get props => [name, email];
}

class AttachmentMetadata extends Equatable {
  final String filename;
  final String mime;
  final String size;

  const AttachmentMetadata({
    required this.filename,
    required this.mime,
    required this.size,
  });

  factory AttachmentMetadata.fromJson(Map<String, dynamic> json) =>
      AttachmentMetadata(
        filename: json['filename'] as String? ?? 'attachment',
        mime: json['mime'] as String? ?? 'application/octet-stream',
        size: json['size'] as String? ?? '',
      );

  @override
  List<Object?> get props => [filename, mime, size];
}

class Attachment extends Equatable {
  final String filename;
  final String? contentId;
  final String mime;
  final String size;

  const Attachment({
    required this.filename,
    this.contentId,
    required this.mime,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        filename: json['filename'] as String? ?? 'attachment',
        contentId: json['content_id'] as String?,
        mime: json['mime'] as String? ?? 'application/octet-stream',
        size: json['size'] as String? ?? '',
      );

  @override
  List<Object?> get props => [filename, contentId, mime, size];
}

class MailMessageMetadata extends Equatable {
  final String id;
  final Address from;
  final List<Address> to;
  final String subject;

  /// Unix timestamp in seconds.
  final int time;
  final String date;
  final String size;
  final bool opened;
  final List<AttachmentMetadata> attachments;
  final String envelopeFrom;
  final List<String> envelopeRecipients;

  const MailMessageMetadata({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.time,
    required this.date,
    required this.size,
    required this.opened,
    required this.attachments,
    required this.envelopeFrom,
    required this.envelopeRecipients,
  });

  factory MailMessageMetadata.fromJson(Map<String, dynamic> json) =>
      MailMessageMetadata(
        id: json['id'] as String,
        from: json['from'] is Map<String, dynamic>
            ? Address.fromJson(json['from'] as Map<String, dynamic>)
            : const Address(),
        to: (json['to'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Address.fromJson)
            .toList(),
        subject: json['subject'] as String? ?? '(no subject)',
        time: (json['time'] as num?)?.toInt() ?? 0,
        date: json['date'] as String? ?? '',
        size: json['size'] as String? ?? '',
        opened: json['opened'] as bool? ?? false,
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AttachmentMetadata.fromJson)
            .toList(),
        envelopeFrom: json['envelope_from'] as String? ?? '',
        envelopeRecipients:
            (json['envelope_recipients'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
      );

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000).toLocal();

  String get displaySubject => subject.trim().isEmpty ? '(no subject)' : subject;

  MailMessageMetadata copyWith({bool? opened}) => MailMessageMetadata(
        id: id,
        from: from,
        to: to,
        subject: subject,
        time: time,
        date: date,
        size: size,
        opened: opened ?? this.opened,
        attachments: attachments,
        envelopeFrom: envelopeFrom,
        envelopeRecipients: envelopeRecipients,
      );

  bool matches(String query) {
    final q = query.toLowerCase();
    return subject.toLowerCase().contains(q) ||
        from.display.toLowerCase().contains(q) ||
        envelopeFrom.toLowerCase().contains(q) ||
        to.any((a) => a.display.toLowerCase().contains(q)) ||
        envelopeRecipients.any((r) => r.toLowerCase().contains(q));
  }

  @override
  List<Object?> get props =>
      [id, from, to, subject, time, date, size, opened, attachments,
       envelopeFrom, envelopeRecipients];
}

class MailMessage extends Equatable {
  final String id;
  final Address from;
  final List<Address> to;
  final String subject;
  final int time;
  final String date;
  final String size;
  final bool opened;
  final String text;
  final String html;
  final List<Attachment> attachments;
  final Map<String, String> headers;
  final String envelopeFrom;
  final List<String> envelopeRecipients;

  const MailMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.time,
    required this.date,
    required this.size,
    required this.opened,
    required this.text,
    required this.html,
    required this.attachments,
    required this.headers,
    required this.envelopeFrom,
    required this.envelopeRecipients,
  });

  factory MailMessage.fromJson(Map<String, dynamic> json) => MailMessage(
        id: json['id'] as String,
        from: json['from'] is Map<String, dynamic>
            ? Address.fromJson(json['from'] as Map<String, dynamic>)
            : const Address(),
        to: (json['to'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Address.fromJson)
            .toList(),
        subject: json['subject'] as String? ?? '(no subject)',
        time: (json['time'] as num?)?.toInt() ?? 0,
        date: json['date'] as String? ?? '',
        size: json['size'] as String? ?? '',
        opened: json['opened'] as bool? ?? false,
        text: json['text'] as String? ?? '',
        html: json['html'] as String? ?? '',
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Attachment.fromJson)
            .toList(),
        headers: (json['headers'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        envelopeFrom: json['envelope_from'] as String? ?? '',
        envelopeRecipients:
            (json['envelope_recipients'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
      );

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000).toLocal();

  String get displaySubject => subject.trim().isEmpty ? '(no subject)' : subject;

  /// Short plain-text preview of the body for notifications: prefers the
  /// text part, falls back to tag-stripped HTML; whitespace collapsed.
  String get snippet {
    var source = text.trim();
    if (source.isEmpty && html.isNotEmpty) {
      source = html
          .replaceAll(
              RegExp(r'<(style|script)[^>]*>.*?</\1>',
                  caseSensitive: false, dotAll: true),
              ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");
    }
    source = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    return source.length <= 140 ? source : '${source.substring(0, 140)}…';
  }

  @override
  List<Object?> get props =>
      [id, from, to, subject, time, date, size, opened, text, html,
       attachments, headers, envelopeFrom, envelopeRecipients];
}
