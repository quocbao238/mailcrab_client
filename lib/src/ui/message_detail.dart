import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/mailbox_bloc.dart';
import '../models/models.dart';
import 'formatting.dart';

class MessageDetailPane extends StatelessWidget {
  final bool showActions;

  const MessageDetailPane({super.key, this.showActions = true});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxBloc, MailboxState>(
      builder: (context, state) {
        final Widget child;
        if (state.selectedId == null) {
          child = const _NoSelection(key: ValueKey('detail-empty'));
        } else if (state.loadingMessage || state.selectedMessage == null) {
          child = const Center(
            key: ValueKey('detail-loading'),
            child: CircularProgressIndicator(),
          );
        } else {
          child = _MessageView(
            key: ValueKey(state.selectedMessage!.id),
            message: state.selectedMessage!,
            showActions: showActions,
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }
}

class MobileMessageScreen extends StatelessWidget {
  const MobileMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxBloc, MailboxState>(
      builder: (context, state) {
        final bloc = context.read<MailboxBloc>();
        final message = state.selectedMessage;
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => bloc.add(const MailboxSelectionCleared()),
            ),
            actions: message == null
                ? null
                : [
                    IconButton(
                      tooltip: 'Open in browser',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(
                        bloc.api.bodyUri(message.id),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete message',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          bloc.add(MailboxMessageDeleted(message.id)),
                    ),
                    const SizedBox(width: 4),
                  ],
          ),
          body: const MessageDetailPane(showActions: false),
        );
      },
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Select a message to read it',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatefulWidget {
  final MailMessage message;
  final bool showActions;

  const _MessageView(
      {super.key, required this.message, required this.showActions});

  @override
  State<_MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<_MessageView> {
  Future<String>? _raw;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final bloc = context.read<MailboxBloc>();

    final tabs = <(Tab, WidgetBuilder)>[
      if (message.html.trim().isNotEmpty)
        (
          const Tab(text: 'HTML'),
          (_) => _HtmlBody(message: message),
        ),
      (
        const Tab(text: 'Text'),
        (_) => _PaddedScroll(
              child: SelectableText(
                message.text.trim().isEmpty ? '(empty body)' : message.text,
              ),
            ),
      ),
      (
        const Tab(text: 'Raw'),
        (_) {
          _raw ??= bloc.api.fetchRaw(message.id);
          return FutureBuilder<String>(
            future: _raw,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text(
                        'Could not load raw message:\n${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _PaddedScroll(
                child: SelectableText(
                  snapshot.data!,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              );
            },
          );
        },
      ),
      (
        const Tab(text: 'Headers'),
        (_) => _HeadersView(headers: message.headers),
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(message: message, showActions: widget.showActions),
          if (message.attachments.isNotEmpty) _AttachmentsRow(message: message),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs.map((t) => t.$1).toList(),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: tabs.map((t) => Builder(builder: t.$2)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final MailMessage message;
  final bool showActions;

  const _Header({required this.message, required this.showActions});

  String _initials(String source) {
    final parts = source
        .replaceAll(RegExp(r'[<>@].*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MailboxBloc>();

    final senderName = message.from.short == '(unknown)'
        ? message.envelopeFrom
        : message.from.short;
    final senderEmail = message.from.email ?? message.envelopeFrom;
    final recipients = message.to.isNotEmpty
        ? message.to.map((a) => a.short).join(', ')
        : message.envelopeRecipients.join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  message.displaySubject,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w500, height: 1.25),
                ),
              ),
              if (showActions) ...[
                IconButton(
                  tooltip: 'Open in browser',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => launchUrl(
                    bloc.api.bodyUri(message.id),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete message',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      bloc.add(MailboxMessageDeleted(message.id)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: Text(
                  _initials(senderName),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatListTime(message.dateTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Tooltip(
                      message:
                          'From $senderEmail\n${formatFullTime(message.dateTime)} · ${message.size}',
                      child: Text(
                        'to $recipients',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _AttachmentsRow extends StatelessWidget {
  final MailMessage message;

  const _AttachmentsRow({required this.message});

  IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MailboxBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < message.attachments.length; i++)
            ActionChip(
              avatar: Icon(_iconFor(message.attachments[i].mime), size: 18),
              label: Text(
                '${message.attachments[i].filename}'
                '${message.attachments[i].size.isNotEmpty ? ' (${message.attachments[i].size})' : ''}',
              ),
              tooltip: 'Download attachment',
              onPressed: () => launchUrl(
                bloc.api.attachmentUri(message.id, i),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

class _HtmlBody extends StatefulWidget {
  final MailMessage message;

  const _HtmlBody({required this.message});

  @override
  State<_HtmlBody> createState() => _HtmlBodyState();
}

class _HtmlBodyState extends State<_HtmlBody> {
  late Future<String> _html;

  @override
  void initState() {
    super.initState();
    _html = _resolveCids();
  }

  @override
  void didUpdateWidget(covariant _HtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _html = _resolveCids();
    }
  }

  Future<String> _resolveCids() async {
    final message = widget.message;
    final api = context.read<MailboxBloc>().api;
    var html = message.html;
    for (var i = 0; i < message.attachments.length; i++) {
      final attachment = message.attachments[i];
      final cid = attachment.contentId;
      if (cid == null || cid.isEmpty) continue;
      final bare = cid.replaceAll(RegExp(r'^<|>$'), '');
      if (!html.contains('cid:$bare')) continue;
      var resolved = api.attachmentUri(message.id, i).toString();
      if (api.authHeaders.isNotEmpty) {
        try {
          final bytes = await api.fetchAttachmentBytes(message.id, i);
          resolved = 'data:${attachment.mime};base64,${base64Encode(bytes)}';
        } catch (_) {
        }
      }
      html = html.replaceAll('cid:$bare', resolved);
    }
    return html;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _html,

      initialData: widget.message.html,
      builder: (context, snapshot) => _PaddedScroll(
        child: HtmlWidget(
          snapshot.data ?? widget.message.html,
          onTapUrl: (url) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return true;
          },
        ),
      ),
    );
  }
}

class _HeadersView extends StatelessWidget {
  final Map<String, String> headers;

  const _HeadersView({required this.headers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = headers.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (keys.isEmpty) {
      return const Center(child: Text('No headers'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              children: [
                TextSpan(
                  text: '$key: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                TextSpan(text: headers[key]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaddedScroll extends StatelessWidget {
  final Widget child;

  const _PaddedScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }
}
