import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/mailbox_bloc.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/sso_session_webview.dart';
import 'sso_login_dialog.dart';

const _githubUrl = 'https://github.com/quocbao238';

Future<void> showSettingsDialog(BuildContext context) {
  final bloc = context.read<MailboxBloc>();
  return showDialog(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const _SettingsDialog()),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  static const _presetColors = <int>[
    AppSettings.defaultSeedColor,
    0xFFD32F2F,
    0xFFC2185B,
    0xFF7B1FA2,
    0xFF3949AB,
    0xFF1976D2,
    0xFF00897B,
    0xFF388E3C,
    0xFFF9A825,
    0xFF5D4037,
  ];

  late final TextEditingController _urlController;
  late final TextEditingController _cookieController;
  late bool _notificationsEnabled;
  late String _themeMode;
  late int _seedColor;
  String? _testResult;
  bool _testing = false;
  NotificationPermissionStatus? _permission;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<MailboxBloc>().state.settings;
    _urlController = TextEditingController(text: settings.serverUrl);
    _cookieController = TextEditingController(text: settings.authCookie);
    _notificationsEnabled = settings.notificationsEnabled;
    _themeMode = settings.themeMode;
    _seedColor = settings.seedColor;
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final status = await context
        .read<MailboxBloc>()
        .notifications
        .checkPermission();
    if (mounted) setState(() => _permission = status);
  }

  Future<void> _requestPermission() async {
    setState(() => _requestingPermission = true);
    final status = await context
        .read<MailboxBloc>()
        .notifications
        .requestPermission();
    if (mounted) {
      setState(() {
        _permission = status;
        _requestingPermission = false;
      });
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    const candidates = [
      'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
      'x-apple.systempreferences:com.apple.preference.notifications',
    ];
    for (final url in candidates) {
      if (await launchUrl(Uri.parse(url))) return;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  void _applyAppearance() {
    final bloc = context.read<MailboxBloc>();
    bloc.add(
      MailboxSettingsUpdated(
        bloc.state.settings.copyWith(
          themeMode: _themeMode,
          seedColor: _seedColor,
        ),
      ),
    );
  }

  Future<void> _signInWithSso() async {
    final cookie = await showSsoLoginDialog(
      context,
      serverUrl: _urlController.text,
    );
    if (!mounted || cookie == null || cookie.isEmpty) return;
    setState(() {
      _cookieController.text = cookie;
      _testResult = null;
    });
    await _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final api = MailCrabApi(
      _urlController.text,
      authCookie: _cookieController.text.trim(),
    );
    try {
      final version = await api.fetchVersion();
      setState(() => _testResult = '✓ Connected — MailCrab $version');
    } catch (e) {
      setState(() => _testResult = '✗ Failed: $e');
    } finally {
      api.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = _testResult?.startsWith('✓') ?? false;

    return AlertDialog(
      title: const Text('Settings'),

      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'MailCrab server URL',
                  hintText: 'http://localhost:1080',
                  helperText:
                      'Path prefix is supported, e.g. http://host:1080/mailcrab',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _testConnection(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cookieController,
                decoration: const InputDecoration(
                  labelText: 'Auth cookie (optional)',
                  hintText: 'session=abc123…',
                  helperText:
                      'For SSO-protected servers: sign in with a browser, then '
                      'copy the Cookie header value from DevTools → Network',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _testConnection(),
              ),
              const SizedBox(height: 8),
              if (WebViewSsoSession().isSupported)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _signInWithSso,
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    label: const Text('Sign in with SSO'),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('Test connection'),
                  ),
                  const SizedBox(width: 12),
                  if (_testResult != null)
                    Expanded(
                      child: Text(
                        _testResult!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ok
                              ? Colors.green.shade700
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify on new mail'),
                subtitle: const Text(
                  'Show a system notification when an email arrives',
                ),
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
              _PermissionSection(
                status: _permission,
                requesting: _requestingPermission,
                onRequest: _requestPermission,
                onOpenSettings: _openSystemNotificationSettings,
              ),
              const Divider(height: 24),
              Text('Appearance', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Applied immediately',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto, size: 16),
                  ),
                  ButtonSegment(
                    value: 'light',
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (selection) {
                  setState(() => _themeMode = selection.first);
                  _applyAppearance();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _presetColors)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() => _seedColor = color);
                        _applyAppearance();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: _seedColor == color
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                        ),
                        child: _seedColor == color
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => launchUrl(
                  Uri.parse(_githubUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'MailCrab Client — github.com/quocbao238',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final bloc = context.read<MailboxBloc>();
            bloc.add(
              MailboxSettingsUpdated(
                bloc.state.settings.copyWith(
                  serverUrl: _urlController.text.trim(),
                  authCookie: _cookieController.text.trim(),
                  notificationsEnabled: _notificationsEnabled,
                  themeMode: _themeMode,
                  seedColor: _seedColor,
                ),
              ),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PermissionSection extends StatelessWidget {
  final NotificationPermissionStatus? status;
  final bool requesting;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  const _PermissionSection({
    required this.status,
    required this.requesting,
    required this.onRequest,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = theme.platform == TargetPlatform.macOS;

    final (chipColor, chipLabel) = switch (status) {
      null => (theme.colorScheme.outline, 'Checking…'),
      NotificationPermissionStatus.granted => (Colors.green, 'Granted'),
      NotificationPermissionStatus.denied => (
        theme.colorScheme.error,
        'Not granted',
      ),
      NotificationPermissionStatus.unknown => (
        theme.colorScheme.outline,
        'Not required',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('System permission:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Icon(Icons.circle, size: 10, color: chipColor),
            const SizedBox(width: 4),
            Text(
              chipLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (status == NotificationPermissionStatus.denied)
              TextButton.icon(
                onPressed: requesting ? null : onRequest,
                icon: requesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('Request permission'),
              ),
          ],
        ),
        if (status == NotificationPermissionStatus.denied) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications are blocked for MailCrab',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'If "Request permission" shows no dialog, the OS remembered '
                  'an earlier denial — enable it manually:\n'
                  '1. Open System Settings → Notifications → MailCrab\n'
                  '2. Turn on "Allow notifications" and pick the "Banners" style\n'
                  '3. Make sure Focus / Do Not Disturb is off',
                  style: theme.textTheme.bodySmall,
                ),
                if (isMacOS) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Open System Settings'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
