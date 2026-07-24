import 'package:flutter_test/flutter_test.dart';
import 'package:mailcrab_client/src/bloc/mailbox_bloc.dart';
import 'package:mailcrab_client/src/models/models.dart';
import 'package:mailcrab_client/src/services/settings_service.dart';

MailMessageMetadata _meta(String id, String subject, {bool opened = false}) =>
    MailMessageMetadata.fromJson({
      'id': id,
      'subject': subject,
      'opened': opened,
      'from': {'name': 'Sender', 'email': 's@test.dev'},
    });

void main() {
  const settings = AppSettings();

  group('MailboxState', () {
    test('visibleMessages applies the filter', () {
      final state = MailboxState(
        settings: settings,
        messages: [_meta('1', 'Invoice ready'), _meta('2', 'Welcome aboard')],
        filter: 'invoice',
      );
      expect(state.visibleMessages.map((m) => m.id), ['1']);
    });

    test('unreadCount counts unopened messages', () {
      final state = MailboxState(
        settings: settings,
        messages: [
          _meta('1', 'a'),
          _meta('2', 'b', opened: true),
          _meta('3', 'c'),
        ],
      );
      expect(state.unreadCount, 2);
    });

    test('copyWith can clear nullable fields explicitly', () {
      final state = MailboxState(
        settings: settings,
        selectedId: 'abc',
        error: 'boom',
      );
      final cleared = state.copyWith(selectedId: null, error: null);
      expect(cleared.selectedId, isNull);
      expect(cleared.error, isNull);

      // Untouched fields survive a copyWith.
      final kept = state.copyWith(filter: 'x');
      expect(kept.selectedId, 'abc');
      expect(kept.error, 'boom');
    });

    test('states with equal contents are equal', () {
      expect(
        MailboxState(settings: settings, messages: [_meta('1', 'a')]),
        MailboxState(settings: settings, messages: [_meta('1', 'a')]),
      );
    });
  });
}
