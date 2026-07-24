import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/mailbox_bloc.dart';
import '../models/models.dart';
import 'formatting.dart';

class MessageDetailPane extends StatelessWidget {
  /// Shows a back button when the layout has no side-by-side list.
  final bool showBack;

  const MessageDetailPane({super.key, required this.showBack});

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
            showBack: showBack,
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
  final bool showBack;

  const _MessageView(
      {super.key, required this.message, required this.showBack});

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
          _Header(message: message, showBack: widget.showBack),
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
  final bool showBack;

  const _Header({required this.message, required this.showBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MailboxBloc>();

    final recipients = message.to.isNotEmpty
        ? message.to.map((a) => a.display).join(', ')
        : message.envelopeRecipients.join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back to list',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      bloc.add(const MailboxSelectionCleared()),
                ),
              Expanded(
                child: SelectableText(
                  message.displaySubject,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
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
          ),
          const SizedBox(height: 4),
          SelectableText.rich(
            TextSpan(
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              children: [
                const TextSpan(
                    text: 'From  ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                    text: message.from.display == '(unknown)'
                        ? message.envelopeFrom
                        : message.from.display),
                const TextSpan(
                    text: '\nTo      ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: recipients),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatFullTime(message.dateTime)}   ·   ${message.size}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 4),
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

class _HtmlBody extends StatelessWidget {
  final MailMessage message;

  const _HtmlBody({required this.message});

  /// Rewrites inline `cid:` image references to MailCrab attachment URLs
  /// so embedded images render in-app.
  String _resolveCids(BuildContext context) {
    var html = message.html;
    final bloc = context.read<MailboxBloc>();
    for (var i = 0; i < message.attachments.length; i++) {
      final cid = message.attachments[i].contentId;
      if (cid == null || cid.isEmpty) continue;
      final bare = cid.replaceAll(RegExp(r'^<|>$'), '');
      html = html.replaceAll(
        'cid:$bare',
        bloc.api.attachmentUri(message.id, i).toString(),
      );
    }
    return html;
  }

  @override
  Widget build(BuildContext context) {
    return _PaddedScroll(
      child: HtmlWidget(
        _resolveCids(context),
        onTapUrl: (url) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return true;
        },
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
