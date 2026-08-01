import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/mailbox_bloc.dart';
import '../services/sso_session_webview.dart';
import 'animated_widgets.dart';
import 'sso_login_dialog.dart';
import 'message_detail.dart';
import 'message_list.dart';
import 'settings_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _wideBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxBloc, MailboxState>(
      builder: (context, state) {
        final bloc = context.read<MailboxBloc>();
        final narrow = MediaQuery.sizeOf(context).width < _wideBreakpoint;

        if (narrow && state.selectedId != null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) bloc.add(const MailboxSelectionCleared());
            },
            child: const MobileMessageScreen(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🦀 '),
                const Text('MailCrab'),
                if (state.unreadCount > 0) ...[
                  const SizedBox(width: 10),
                  Badge.count(count: state.unreadCount),
                ],
              ],
            ),
            actions: narrow

                ? [
                    _StatusChip(state: state, compact: true),
                    PopupMenuButton<_MenuAction>(
                      tooltip: 'Menu',
                      onSelected: (action) => switch (action) {
                        _MenuAction.refresh =>
                          bloc.add(const MailboxRefreshRequested()),
                        _MenuAction.deleteAll => _confirmDeleteAll(context),
                        _MenuAction.settings => showSettingsDialog(context),
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _MenuAction.refresh,
                          child: ListTile(
                            leading: Icon(Icons.refresh),
                            title: Text('Refresh'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.deleteAll,
                          child: ListTile(
                            leading: Icon(Icons.delete_sweep_outlined),
                            title: Text('Delete all messages'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _MenuAction.settings,
                          child: ListTile(
                            leading: Icon(Icons.settings_outlined),
                            title: Text('Settings'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ]
                : [
                    _StatusChip(state: state),
                    SpinIconButton(
                      tooltip: 'Refresh',
                      icon: Icons.refresh,
                      spinning: state.loadingList,
                      onPressed: () =>
                          bloc.add(const MailboxRefreshRequested()),
                    ),
                    BouncyIconButton(
                      tooltip: 'Delete all messages',
                      icon: Icons.delete_sweep_outlined,
                      onPressed: () => _confirmDeleteAll(context),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => showSettingsDialog(context),
                    ),
                    const SizedBox(width: 4),
                  ],
          ),
          body: Column(
            children: [
              if (state.networkStatus == NetworkStatus.offline)
                MaterialBanner(
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                  leading: const Icon(Icons.wifi_off),
                  content: const Text(
                      'No internet connection — reconnecting automatically when the network returns.'),
                  actions: const [SizedBox.shrink()],
                ),
              if (state.serverStatus == ServerStatus.unauthorized)
                _AuthRequiredBanner(state: state)
              else if (state.error != null)
                MaterialBanner(
                  content: Text(state.error!),
                  leading: const Icon(Icons.error_outline),
                  actions: [
                    TextButton(
                      onPressed: () => bloc.add(const MailboxErrorCleared()),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _wideBreakpoint;
                    if (wide) {
                      return const Row(
                        children: [
                          SizedBox(width: 380, child: MessageListPane()),
                          VerticalDivider(width: 1),
                          Expanded(child: MessageDetailPane()),
                        ],
                      );
                    }
                    return const MessageListPane();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final bloc = context.read<MailboxBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all messages?'),
        content: const Text(
            'This removes every message stored on the MailCrab server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(const MailboxAllDeleted());
    }
  }
}

enum _MenuAction { refresh, deleteAll, settings }

class _AuthRequiredBanner extends StatelessWidget {
  final MailboxState state;

  const _AuthRequiredBanner({required this.state});

  Future<void> _signIn(BuildContext context) async {
    final bloc = context.read<MailboxBloc>();
    final cookie = await showSsoLoginDialog(
      context,
      serverUrl: state.settings.serverUrl,
    );
    if (cookie == null || cookie.isEmpty) return;
    bloc.add(MailboxSettingsUpdated(
      bloc.state.settings.copyWith(authCookie: cookie),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUseWebView = WebViewSsoSession().isSupported;
    return MaterialBanner(
      backgroundColor: theme.colorScheme.errorContainer,
      leading: const Icon(Icons.lock_outline),
      content: Text(
        state.error ?? 'Sign-in required — add an auth cookie in Settings.',
      ),
      actions: [
        if (canUseWebView)
          TextButton(
            onPressed: () => _signIn(context),
            child: const Text('Sign in'),
          )
        else
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(state.settings.serverUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Sign in in browser'),
          ),
        TextButton(
          onPressed: () => showSettingsDialog(context),
          child: const Text('Settings'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MailboxState state;

  final bool compact;

  const _StatusChip({required this.state, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final noNetwork = state.networkStatus == NetworkStatus.offline;
    final (color, label) = noNetwork
        ? (Colors.red, 'No internet')
        : switch (state.serverStatus) {
            ServerStatus.connected => (Colors.green, 'Live'),
            ServerStatus.connecting => (Colors.orange, 'Connecting…'),
            ServerStatus.polling => (Colors.orange, 'Polling'),
            ServerStatus.offline => (Colors.red, 'Offline'),
            ServerStatus.reauthenticating => (Colors.orange, 'Signing in…'),
            ServerStatus.unauthorized => (Colors.red, 'Sign-in required'),
          };

    return Tooltip(
      message: noNetwork
          ? 'Device has no internet connection'
          : switch (state.serverStatus) {
              ServerStatus.connected =>
                'Connected — new mail arrives in real time',
              ServerStatus.connecting => 'Connecting to MailCrab…',
              ServerStatus.polling =>
                'WebSocket unavailable (proxy blocks upgrades?) — '
                    'checking for new mail every 10 seconds',
              ServerStatus.offline =>
                'Cannot reach MailCrab — retrying automatically',
              ServerStatus.reauthenticating =>
                'Session expired — renewing it in the background',
              ServerStatus.unauthorized =>
                'The server requires an SSO sign-in — add or refresh the '
                    'auth cookie in Settings',
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (noNetwork)
              Icon(Icons.wifi_off, size: 14, color: color)
            else
              StatusPingDot(
                color: color,
                pinging: state.serverStatus == ServerStatus.connected,
              ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
