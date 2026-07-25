import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/mailbox_bloc.dart';
import '../models/models.dart';
import 'formatting.dart';

class MessageListPane extends StatefulWidget {
  const MessageListPane({super.key});

  @override
  State<MessageListPane> createState() => _MessageListPaneState();
}

class _MessageListPaneState extends State<MessageListPane> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<MailboxBloc>();
    bloc.add(const MailboxRefreshRequested());
    // Keep the spinner visible until the reload finishes.
    await bloc.stream
        .firstWhere((s) => !s.loadingList)
        .timeout(const Duration(seconds: 10), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxBloc, MailboxState>(
      builder: (context, state) {
        final messages = state.visibleMessages;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              // Gmail-style pill search bar.
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => context
                      .read<MailboxBloc>()
                      .add(MailboxFilterChanged(value)),
                  decoration: InputDecoration(
                    hintText: 'Search in mail',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    suffixIcon: state.filter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<MailboxBloc>()
                                  .add(const MailboxFilterChanged(''));
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            if (state.loadingList) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: messages.isEmpty
                    ? _EmptyState(hasFilter: state.filter.trim().isNotEmpty)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => _MessageTile(
                          message: messages[index],
                          selected: messages[index].id == state.selectedId,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageTile extends StatefulWidget {
  final MailMessageMetadata message;
  final bool selected;

  const _MessageTile({required this.message, required this.selected});

  @override
  State<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<_MessageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.message;
    final unread = !message.opened;
    final titleStyle = TextStyle(
      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
    );

    return Dismissible(
      key: ValueKey('dismiss-${message.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          context.read<MailboxBloc>().add(MailboxMessageDeleted(message.id)),
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ListTile(
        selected: widget.selected,
        selectedTileColor:
            theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        onTap: () => context
            .read<MailboxBloc>()
            .add(MailboxMessageSelected(message.id)),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: unread
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: unread
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
          child: Text(
            _initials(message),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          message.from.short == '(unknown)'
              ? message.envelopeFrom
              : message.from.short,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: Text(
          message.displaySubject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle.copyWith(fontSize: 13),
        ),
        trailing: _hovered
            ? IconButton(
                tooltip: 'Delete message',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => context
                    .read<MailboxBloc>()
                    .add(MailboxMessageDeleted(message.id)),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatListTime(message.dateTime),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (message.attachments.isNotEmpty)
                    Icon(Icons.attach_file,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
        ),
      ),
    );
  }

  String _initials(MailMessageMetadata m) {
    final source = m.from.short == '(unknown)' ? m.envelopeFrom : m.from.short;
    final parts = source
        .replaceAll(RegExp(r'[<>@].*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦀', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            Text(
              hasFilter ? 'No messages match your search' : 'No messages yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!hasFilter) ...[
              const SizedBox(height: 8),
              Text(
                'Point your app\'s SMTP settings at MailCrab\n(default: localhost:1025) and mail will show up here.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
