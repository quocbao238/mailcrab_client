import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/bloc/mailbox_bloc.dart';
import 'src/services/notification_service.dart';
import 'src/services/settings_service.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsService.load();
  final notifications = NotificationService();
  // Fire-and-forget: the OS permission prompt must not block first paint.
  unawaited(notifications.init());

  runApp(MailCrabApp(settings: settings, notifications: notifications));
}

class MailCrabApp extends StatelessWidget {
  final AppSettings settings;
  final NotificationService notifications;

  const MailCrabApp({
    super.key,
    required this.settings,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MailboxBloc(
        settings: settings,
        notifications: notifications,
      )..add(const MailboxStarted()),
      child: BlocBuilder<MailboxBloc, MailboxState>(
        buildWhen: (prev, curr) => prev.settings != curr.settings,
        builder: (context, state) {
          final seed = Color(state.settings.seedColor);
          final mode = switch (state.settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            title: 'MailCrab Client',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: mode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
