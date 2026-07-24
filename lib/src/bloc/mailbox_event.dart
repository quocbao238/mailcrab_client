part of 'mailbox_bloc.dart';

sealed class MailboxEvent {
  const MailboxEvent();
}

/// Kick off: initial fetch, WebSocket connection and connectivity watch.
final class MailboxStarted extends MailboxEvent {
  const MailboxStarted();
}

final class MailboxRefreshRequested extends MailboxEvent {
  const MailboxRefreshRequested();
}

final class MailboxMessageSelected extends MailboxEvent {
  final String id;
  const MailboxMessageSelected(this.id);
}

final class MailboxSelectionCleared extends MailboxEvent {
  const MailboxSelectionCleared();
}

final class MailboxFilterChanged extends MailboxEvent {
  final String filter;
  const MailboxFilterChanged(this.filter);
}

final class MailboxMessageDeleted extends MailboxEvent {
  final String id;
  const MailboxMessageDeleted(this.id);
}

final class MailboxAllDeleted extends MailboxEvent {
  const MailboxAllDeleted();
}

final class MailboxSettingsUpdated extends MailboxEvent {
  final AppSettings settings;
  const MailboxSettingsUpdated(this.settings);
}

final class MailboxErrorCleared extends MailboxEvent {
  const MailboxErrorCleared();
}

/// Internal: a new message arrived over the WebSocket.
final class _MailReceived extends MailboxEvent {
  final MailMessageMetadata metadata;
  const _MailReceived(this.metadata);
}

/// Internal: WebSocket connection status changed.
final class _WsStatusChanged extends MailboxEvent {
  final WsStatus status;
  const _WsStatusChanged(this.status);
}

/// Internal: device connectivity changed (connectivity_plus).
final class _ConnectivityChanged extends MailboxEvent {
  final List<ConnectivityResult> results;
  const _ConnectivityChanged(this.results);
}

/// Internal: periodic poll while the WebSocket is down.
final class _PollTick extends MailboxEvent {
  const _PollTick();
}
