import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/mailbox_bloc.dart';
import 'animated_widgets.dart';
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

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
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
            ),
            actions: [
              _StatusChip(state: state),
              SpinIconButton(
                tooltip: 'Refresh',
                icon: Icons.refresh,
                spinning: state.loadingList,
                onPressed: () => bloc.add(const MailboxRefreshRequested()),
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
              if (state.error != null)
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
                          Expanded(child: MessageDetailPane(showBack: false)),
                        ],
                      );
                    }
                    return state.selectedId == null
                        ? const MessageListPane()
                        : const MessageDetailPane(showBack: true);
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

class _StatusChip extends StatelessWidget {
  final MailboxState state;

  const _StatusChip({required this.state});

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
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
