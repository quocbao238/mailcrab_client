import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/mailbox_repository.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/sso_session.dart';
import '../services/ws_listener.dart';

part 'mailbox_event.dart';
part 'mailbox_state.dart';

class MailboxBloc extends Bloc<MailboxEvent, MailboxState> {
  static const pollInterval = Duration(seconds: 10);

  final NotificationService _notifications;
  final Connectivity _connectivity;
  final SsoSessionProvider _sso;
  final MailboxRepositoryFactory _repositoryFactory;
  final BadgeService _badge = BadgeService();

  MailboxRepository _api;
  WsListener? _ws;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _pollInFlight = false;

  bool _renewAttempted = false;

  bool _hasFetchedOnce = false;

  MailboxBloc({
    required AppSettings settings,
    required this._notifications,
    Connectivity? connectivity,
    this._sso = const NoSsoSession(),
    MailboxRepositoryFactory repositoryFactory = MailCrabApi.create,
  })  : _connectivity = connectivity ?? Connectivity(),
        _repositoryFactory = repositoryFactory,
        _api = repositoryFactory(settings.serverUrl, settings.authCookie),
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

    _notifications.onSelectMessage =
        (id) => _safeAdd(MailboxMessageSelected(id));
  }

  void _safeAdd(MailboxEvent event) {
    if (!isClosed) add(event);
  }

  MailboxRepository get api => _api;

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
      _renewAttempted = false;
      final selectionGone = state.selectedId != null &&
          !messages.any((m) => m.id == state.selectedId);
      emit(state.copyWith(
        messages: messages,
        loadingList: false,
        selectedId: selectionGone ? null : state.selectedId,
        selectedMessage: selectionGone ? null : state.selectedMessage,
      ));
    } on MailCrabAuthException catch (e) {
      await _handleAuthFailure(emit, e);
    } catch (e) {
      emit(state.copyWith(
        loadingList: false,
        error: 'Could not load messages: $e',
      ));
    }
  }

  Future<void> _handleAuthFailure(
      Emitter<MailboxState> emit, MailCrabAuthException e) async {
    if (!_sso.isSupported || _renewAttempted) {
      _enterUnauthorized(emit, e);
      return;
    }
    _renewAttempted = true;
    _stopPolling();
    emit(state.copyWith(
      serverStatus: ServerStatus.reauthenticating,
      loadingList: false,
      error: null,
    ));

    final cookie = await _sso.renew(_api.base);
    if (cookie == null || cookie == state.settings.authCookie) {
      _enterUnauthorized(emit, e);
      return;
    }

    final settings = state.settings.copyWith(authCookie: cookie);

    emit(state.copyWith(
      settings: settings,
      serverStatus: ServerStatus.connecting,
    ));
    await SettingsService.save(settings);
    _api.dispose();
    _api = _repositoryFactory(settings.serverUrl, cookie);
    _connectWs();

    await _loadMessages(emit);
  }

  void _enterUnauthorized(Emitter<MailboxState> emit, MailCrabAuthException e) {
    _stopPolling();
    _ws?.dispose();
    _ws = null;
    emit(state.copyWith(
      loadingList: false,
      serverStatus: ServerStatus.unauthorized,
      error: e.message,
    ));
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
    } on MailCrabAuthException catch (e) {
      emit(state.copyWith(loadingMessage: false));
      await _handleAuthFailure(emit, e);
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
    } on MailCrabAuthException catch (e) {
      await _handleAuthFailure(emit, e);
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
    } on MailCrabAuthException catch (e) {
      await _handleAuthFailure(emit, e);
    } catch (e) {
      emit(state.copyWith(error: 'Could not delete messages: $e'));
    }
  }

  Future<void> _onSettingsUpdated(
      MailboxSettingsUpdated event, Emitter<MailboxState> emit) async {
    final serverChanged =
        event.settings.serverUrl != state.settings.serverUrl ||
            event.settings.authCookie != state.settings.authCookie;
    emit(state.copyWith(settings: event.settings));
    await SettingsService.save(event.settings);

    if (serverChanged) {
      _stopPolling();
      _hasFetchedOnce = false;

      _renewAttempted = false;
      _api.dispose();
      _api = _repositoryFactory(
          event.settings.serverUrl, event.settings.authCookie);
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

  Future<void> _notifyWithPreview(MailMessageMetadata meta) async {
    String? snippet;
    try {
      final full = await _api.fetchMessage(meta.id);
      snippet = full.snippet;
    } catch (_) {
    }
    await _notifications.showNewMail(meta, snippet: snippet);
  }

  Future<void> _onWsStatusChanged(
      _WsStatusChanged event, Emitter<MailboxState> emit) async {
    if (state.serverStatus == ServerStatus.unauthorized) return;
    final wsDownStatuses = {ServerStatus.offline, ServerStatus.polling};

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

    if (regained) await _loadMessages(emit);
  }

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
      _renewAttempted = false;
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
    } on MailCrabAuthException catch (e) {
      await _handleAuthFailure(emit, e);
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
    _pollTimer =
        Timer.periodic(pollInterval, (_) => _safeAdd(const _PollTick()));
    _safeAdd(const _PollTick());
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
      _connectWs();
      await _loadMessages(emit);
    }
  }

  void _watchConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged
        .listen((results) => _safeAdd(_ConnectivityChanged(results)));
    _connectivity
        .checkConnectivity()
        .then((results) => _safeAdd(_ConnectivityChanged(results)))
        .catchError((Object _) {});
  }

  void _connectWs() {
    if (state.serverStatus == ServerStatus.unauthorized) return;
    _ws?.dispose();
    _ws = WsListener(
      wsUri: _api.wsUri,
      headers: _api.authHeaders,
      onMessage: (meta) => _safeAdd(_MailReceived(meta)),
      onStatus: (status) => _safeAdd(_WsStatusChanged(status)),
    )..connect();
  }

  void _sort(List<MailMessageMetadata> messages) =>
      messages.sort((a, b) => b.time.compareTo(a.time));

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
