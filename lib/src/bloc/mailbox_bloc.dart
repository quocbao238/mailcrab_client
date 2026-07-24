import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/ws_listener.dart';

part 'mailbox_event.dart';
part 'mailbox_state.dart';

class MailboxBloc extends Bloc<MailboxEvent, MailboxState> {
  /// Poll interval used when the WebSocket is unavailable but HTTP works.
  static const pollInterval = Duration(seconds: 10);

  final NotificationService _notifications;
  final Connectivity _connectivity;
  final BadgeService _badge = BadgeService();

  MailCrabApi _api;
  WsListener? _ws;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _pollInFlight = false;

  /// Until the first successful list fetch, "unseen id" does not mean "new
  /// mail" — suppress notifications so startup doesn't replay the mailbox.
  bool _hasFetchedOnce = false;

  MailboxBloc({
    required AppSettings settings,
    required this._notifications,
    Connectivity? connectivity,
  })  : _connectivity = connectivity ?? Connectivity(),
        _api = MailCrabApi(settings.serverUrl),
        super(MailboxState(settings: settings)) {
    on<MailboxStarted>(_onStarted);
    on<MailboxRefreshRequested>(_onRefresh);
    on<MailboxMessageSelected>(_onSelect);
    on<MailboxSelectionCleared>(
        (_, emit) => emit(state.copyWith(selectedId: null, selectedMessage: null)));
    on<MailboxFilterChanged>(
        (event, emit) => emit(state.copyWith(filter: event.filter)));
    on<MailboxMessageDeleted>(_onDelete);
    on<MailboxAllDeleted>(_onDeleteAll);
    on<MailboxSettingsUpdated>(_onSettingsUpdated);
    on<MailboxErrorCleared>((_, emit) => emit(state.copyWith(error: null)));
    on<_MailReceived>(_onMailReceived);
    on<_WsStatusChanged>(_onWsStatusChanged);
    on<_ConnectivityChanged>(_onConnectivityChanged);
    on<_PollTick>(_onPollTick);

    _notifications.onSelectMessage = (id) => add(MailboxMessageSelected(id));
  }

  /// Exposed for the UI to build attachment/body URLs and fetch raw content.
  MailCrabApi get api => _api;

  /// Exposed for the settings UI to check/request notification permission.
  NotificationService get notifications => _notifications;

  Future<void> _onStarted(
      MailboxStarted event, Emitter<MailboxState> emit) async {
    _watchConnectivity();
    _connectWs();
    await _loadMessages(emit);
  }

  Future<void> _onRefresh(
      MailboxRefreshRequested event, Emitter<MailboxState> emit) async {
    await _loadMessages(emit);
  }

  Future<void> _loadMessages(Emitter<MailboxState> emit) async {
    emit(state.copyWith(loadingList: true, error: null));
    try {
      final messages = await _api.fetchMessages();
      _sort(messages);
      _hasFetchedOnce = true;
      final selectionGone = state.selectedId != null &&
          !messages.any((m) => m.id == state.selectedId);
      emit(state.copyWith(
        messages: messages,
        loadingList: false,
        selectedId: selectionGone ? null : state.selectedId,
        selectedMessage: selectionGone ? null : state.selectedMessage,
      ));
    } catch (e) {
      emit(state.copyWith(
        loadingList: false,
        error: 'Could not load messages: $e',
      ));
    }
  }

  Future<void> _onSelect(
      MailboxMessageSelected event, Emitter<MailboxState> emit) async {
    final id = event.id;
    emit(state.copyWith(
      selectedId: id,
      selectedMessage: null,
      loadingMessage: true,
      messages: _withOpened(id),
    ));
    _ws?.markOpened(id);

    try {
      final message = await _api.fetchMessage(id);
      if (state.selectedId == id) {
        emit(state.copyWith(selectedMessage: message, loadingMessage: false));
      }
    } catch (e) {
      if (state.selectedId == id) {
        emit(state.copyWith(
          loadingMessage: false,
          error: 'Could not load message: $e',
        ));
      }
    }
  }

  List<MailMessageMetadata> _withOpened(String id) => [
        for (final m in state.messages)
          m.id == id && !m.opened ? m.copyWith(opened: true) : m
      ];

  Future<void> _onDelete(
      MailboxMessageDeleted event, Emitter<MailboxState> emit) async {
    try {
      await _api.deleteMessage(event.id);
      final gone = state.selectedId == event.id;
      emit(state.copyWith(
        messages: state.messages.where((m) => m.id != event.id).toList(),
        selectedId: gone ? null : state.selectedId,
        selectedMessage: gone ? null : state.selectedMessage,
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Could not delete message: $e'));
    }
  }

  Future<void> _onDeleteAll(
      MailboxAllDeleted event, Emitter<MailboxState> emit) async {
    try {
      await _api.deleteAll();
      emit(state.copyWith(
        messages: const [],
        selectedId: null,
        selectedMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Could not delete messages: $e'));
    }
  }

  Future<void> _onSettingsUpdated(
      MailboxSettingsUpdated event, Emitter<MailboxState> emit) async {
    final serverChanged =
        event.settings.serverUrl != state.settings.serverUrl;
    emit(state.copyWith(settings: event.settings));
    await SettingsService.save(event.settings);

    if (serverChanged) {
      _stopPolling();
      _hasFetchedOnce = false;
      _api.dispose();
      _api = MailCrabApi(event.settings.serverUrl);
      emit(state.copyWith(
        messages: const [],
        selectedId: null,
        selectedMessage: null,
        serverStatus: ServerStatus.connecting,
      ));
      _connectWs();
      await _loadMessages(emit);
    }
  }

  Future<void> _onMailReceived(
      _MailReceived event, Emitter<MailboxState> emit) async {
    final meta = event.metadata;
    if (state.messages.any((m) => m.id == meta.id)) return;
    final messages = [meta, ...state.messages];
    _sort(messages);
    emit(state.copyWith(messages: messages));
    if (state.settings.notificationsEnabled) {
      await _notifyWithPreview(meta);
    }
  }

  /// The WebSocket only carries metadata, so fetch the full message to show
  /// a body preview in the notification. Read-only on the server — it does
  /// NOT mark the message as opened.
  Future<void> _notifyWithPreview(MailMessageMetadata meta) async {
    String? snippet;
    try {
      final full = await _api.fetchMessage(meta.id);
      snippet = full.snippet;
    } catch (_) {
      // Preview is best-effort; notify with the subject alone.
    }
    await _notifications.showNewMail(meta, snippet: snippet);
  }

  Future<void> _onWsStatusChanged(
      _WsStatusChanged event, Emitter<MailboxState> emit) async {
    final wsDownStatuses = {ServerStatus.offline, ServerStatus.polling};
    // While the polling fallback is delivering mail, WS retry cycles
    // (connecting → disconnected → …) should not flicker the status chip.
    final mapped = switch (event.status) {
      WsStatus.connected => ServerStatus.connected,
      WsStatus.connecting => state.serverStatus == ServerStatus.polling
          ? ServerStatus.polling
          : ServerStatus.connecting,
      WsStatus.disconnected => wsDownStatuses.contains(state.serverStatus)
          ? state.serverStatus
          : ServerStatus.offline,
    };
    if (mapped == ServerStatus.connected) {
      _stopPolling();
    } else if (mapped == ServerStatus.offline) {
      _startPolling();
    }
    if (mapped == state.serverStatus) return;
    final regained = wsDownStatuses.contains(state.serverStatus) &&
        mapped == ServerStatus.connected;
    emit(state.copyWith(serverStatus: mapped));
    // Catch up on mail that arrived while the socket was down.
    if (regained) await _loadMessages(emit);
  }

  /// Fallback for servers whose proxy blocks WebSocket upgrades: fetch the
  /// message list, notify for ids we have not seen, and reflect a degraded
  /// but functional connection in the UI.
  Future<void> _onPollTick(_PollTick event, Emitter<MailboxState> emit) async {
    if (_pollInFlight || state.serverStatus == ServerStatus.connected) return;
    _pollInFlight = true;
    try {
      final fetched = await _api.fetchMessages();
      _sort(fetched);
      final known = state.messages.map((m) => m.id).toSet();
      final fresh =
          fetched.where((m) => !known.contains(m.id)).toList().reversed;
      final notifyForFresh = _hasFetchedOnce;
      _hasFetchedOnce = true;
      if (state.serverStatus != ServerStatus.connected) {
        debugPrint(
            'MailCrab poll: ${fetched.length} messages, ${fresh.length} new');
        emit(state.copyWith(
          messages: fetched,
          serverStatus: ServerStatus.polling,
        ));
        if (notifyForFresh && state.settings.notificationsEnabled) {
          for (final meta in fresh) {
            await _notifyWithPreview(meta);
          }
        }
      }
    } catch (_) {
      if (state.serverStatus == ServerStatus.polling) {
        emit(state.copyWith(serverStatus: ServerStatus.offline));
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => add(const _PollTick()));
    add(const _PollTick());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onConnectivityChanged(
      _ConnectivityChanged event, Emitter<MailboxState> emit) async {
    final online = event.results
        .any((r) => r != ConnectivityResult.none);
    final mapped = online ? NetworkStatus.online : NetworkStatus.offline;
    if (mapped == state.networkStatus) return;
    final regained = state.networkStatus == NetworkStatus.offline && online;
    emit(state.copyWith(networkStatus: mapped));
    if (regained) {
      // Reconnect immediately instead of waiting out the backoff.
      _connectWs();
      await _loadMessages(emit);
    }
  }

  void _watchConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged
        .listen((results) => add(_ConnectivityChanged(results)));
    _connectivity
        .checkConnectivity()
        .then((results) => add(_ConnectivityChanged(results)))
        .catchError((Object _) {});
  }

  void _connectWs() {
    _ws?.dispose();
    _ws = WsListener(
      wsUri: _api.wsUri,
      onMessage: (meta) => add(_MailReceived(meta)),
      onStatus: (status) => add(_WsStatusChanged(status)),
    )..connect();
  }

  void _sort(List<MailMessageMetadata> messages) =>
      messages.sort((a, b) => b.time.compareTo(a.time)); // newest first

  /// Keeps the app-icon badge in sync with the unread count on every
  /// state transition, regardless of which event caused it.
  @override
  void onChange(Change<MailboxState> change) {
    super.onChange(change);
    _badge.setCount(change.nextState.unreadCount);
  }

  @override
  Future<void> close() async {
    _stopPolling();
    await _connectivitySub?.cancel();
    _ws?.dispose();
    _api.dispose();
    return super.close();
  }
}
