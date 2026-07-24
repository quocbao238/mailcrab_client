part of 'mailbox_bloc.dart';

/// Health of the MailCrab server connection.
/// [polling] means the WebSocket is unavailable (e.g. a proxy strips the
/// upgrade headers) but HTTP works, so the app falls back to polling.
enum ServerStatus { connecting, connected, polling, offline }

/// Device network connectivity, from connectivity_plus.
enum NetworkStatus { online, offline }

class MailboxState extends Equatable {
  final AppSettings settings;
  final List<MailMessageMetadata> messages;
  final String filter;
  final String? selectedId;
  final MailMessage? selectedMessage;
  final bool loadingList;
  final bool loadingMessage;
  final ServerStatus serverStatus;
  final NetworkStatus networkStatus;
  final String? error;

  const MailboxState({
    required this.settings,
    this.messages = const [],
    this.filter = '',
    this.selectedId,
    this.selectedMessage,
    this.loadingList = false,
    this.loadingMessage = false,
    this.serverStatus = ServerStatus.connecting,
    this.networkStatus = NetworkStatus.online,
    this.error,
  });

  List<MailMessageMetadata> get visibleMessages {
    final query = filter.trim();
    if (query.isEmpty) return messages;
    return messages.where((m) => m.matches(query)).toList();
  }

  int get unreadCount => messages.where((m) => !m.opened).length;

  static const _unset = Object();

  MailboxState copyWith({
    AppSettings? settings,
    List<MailMessageMetadata>? messages,
    String? filter,
    Object? selectedId = _unset,
    Object? selectedMessage = _unset,
    bool? loadingList,
    bool? loadingMessage,
    ServerStatus? serverStatus,
    NetworkStatus? networkStatus,
    Object? error = _unset,
  }) =>
      MailboxState(
        settings: settings ?? this.settings,
        messages: messages ?? this.messages,
        filter: filter ?? this.filter,
        selectedId:
            selectedId == _unset ? this.selectedId : selectedId as String?,
        selectedMessage: selectedMessage == _unset
            ? this.selectedMessage
            : selectedMessage as MailMessage?,
        loadingList: loadingList ?? this.loadingList,
        loadingMessage: loadingMessage ?? this.loadingMessage,
        serverStatus: serverStatus ?? this.serverStatus,
        networkStatus: networkStatus ?? this.networkStatus,
        error: error == _unset ? this.error : error as String?,
      );

  @override
  List<Object?> get props => [
        settings,
        messages,
        filter,
        selectedId,
        selectedMessage,
        loadingList,
        loadingMessage,
        serverStatus,
        networkStatus,
        error,
      ];
}
