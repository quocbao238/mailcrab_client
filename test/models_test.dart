import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mailcrab_client/src/models/models.dart';
import 'package:mailcrab_client/src/services/api_client.dart';

void main() {
  group('MailMessageMetadata', () {
    test('parses MailCrab JSON', () {
      const raw = '''
      {
        "id": "0e9b81c4-4c11-4a6e-9f0e-5f7f3b1e2a10",
        "from": {"name": "Ferris", "email": "ferris@example.com"},
        "to": [{"name": null, "email": "dev@example.com"}],
        "subject": "Hello",
        "time": 1753280000,
        "date": "2026-07-23 15:33:20 UTC",
        "size": "1.2 kB",
        "opened": false,
        "attachments": [{"filename": "a.pdf", "mime": "application/pdf", "size": "10 kB"}],
        "envelope_from": "ferris@example.com",
        "envelope_recipients": ["dev@example.com"]
      }
      ''';
      final meta = MailMessageMetadata.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);

      expect(meta.id, '0e9b81c4-4c11-4a6e-9f0e-5f7f3b1e2a10');
      expect(meta.from.display, 'Ferris <ferris@example.com>');
      expect(meta.from.short, 'Ferris');
      expect(meta.to.single.display, 'dev@example.com');
      expect(meta.opened, isFalse);
      expect(meta.attachments.single.filename, 'a.pdf');
      expect(meta.dateTime.millisecondsSinceEpoch, 1753280000 * 1000);
    });

    test('tolerates missing optional fields', () {
      final meta = MailMessageMetadata.fromJson({'id': 'x'});
      expect(meta.subject, '(no subject)');
      expect(meta.to, isEmpty);
      expect(meta.opened, isFalse);
      expect(meta.from.display, '(unknown)');
    });

    test('matches filters on sender and subject', () {
      final meta = MailMessageMetadata.fromJson({
        'id': 'x',
        'subject': 'Password reset',
        'from': {'name': 'Support', 'email': 'support@shop.test'},
        'envelope_from': 'bounce@shop.test',
      });
      expect(meta.matches('password'), isTrue);
      expect(meta.matches('support'), isTrue);
      expect(meta.matches('bounce'), isTrue);
      expect(meta.matches('nomatch'), isFalse);
    });
  });

  group('MailMessage', () {
    test('parses full message with headers', () {
      final message = MailMessage.fromJson({
        'id': 'y',
        'subject': 'Hi',
        'text': 'plain body',
        'html': '<p>html body</p>',
        'headers': {'Content-Type': 'text/html'},
        'attachments': [
          {
            'filename': 'logo.png',
            'content_id': 'logo123',
            'mime': 'image/png',
            'size': '2 kB'
          }
        ],
      });
      expect(message.text, 'plain body');
      expect(message.html, '<p>html body</p>');
      expect(message.headers['Content-Type'], 'text/html');
      expect(message.attachments.single.contentId, 'logo123');
    });

    test('snippet prefers text and collapses whitespace', () {
      final message = MailMessage.fromJson({
        'id': 'z',
        'text': '  Your OTP is\n\n 123456.  ',
        'html': '<b>ignored</b>',
      });
      expect(message.snippet, 'Your OTP is 123456.');
    });

    test('snippet strips tags/entities from HTML when text is empty', () {
      final message = MailMessage.fromJson({
        'id': 'z',
        'text': '',
        'html':
            '<style>p{color:red}</style><p>Hello &amp; welcome,&nbsp;<b>Bao</b>!</p>',
      });
      expect(message.snippet, 'Hello & welcome, Bao !');
    });

    test('snippet truncates long bodies at 140 chars', () {
      final message = MailMessage.fromJson({
        'id': 'z',
        'text': 'x' * 300,
      });
      expect(message.snippet.length, 141); // 140 + ellipsis
      expect(message.snippet.endsWith('…'), isTrue);
    });
  });

  group('MailCrabApi URL handling', () {
    test('normalizes bare host', () {
      final api = MailCrabApi('localhost:1080');
      expect(api.base.toString(), 'http://localhost:1080');
      expect(api.wsUri.toString(), 'ws://localhost:1080/ws');
    });

    test('keeps path prefix and strips trailing slash', () {
      final api = MailCrabApi('https://mail.example.com/mailcrab/');
      expect(api.base.toString(), 'https://mail.example.com/mailcrab');
      expect(api.wsUri.toString(), 'wss://mail.example.com/mailcrab/ws');
      expect(api.attachmentUri('abc', 2).toString(),
          'https://mail.example.com/mailcrab/api/message/abc/attachment/2');
    });

    test('falls back to default for empty input', () {
      final api = MailCrabApi('   ');
      expect(api.base.toString(), 'http://localhost:1080');
    });
  });
}
