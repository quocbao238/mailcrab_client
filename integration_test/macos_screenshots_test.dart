// Captures desktop-layout screenshots on macOS via RepaintBoundary
// (no screen-recording permission needed).
//
// Run (with MailCrab on localhost:1080 seeded with demo mail):
//   flutter test integration_test/macos_screenshots_test.dart -d macos \
//     --dart-define=SCREENSHOT_MODE=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mailcrab_client/main.dart';
import 'package:mailcrab_client/src/bloc/mailbox_bloc.dart';
import 'package:mailcrab_client/src/services/notification_service.dart';
import 'package:mailcrab_client/src/services/settings_service.dart';
import 'package:mailcrab_client/src/ui/home_page.dart';

final _rootKey = GlobalKey();

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw StateError('pumpUntil timed out waiting for $finder');
}

Future<void> settle(WidgetTester tester,
    [Duration duration = const Duration(milliseconds: 1200)]) async {
  final frames = duration.inMilliseconds ~/ 50;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> capture(String name) async {
  final boundary =
      _rootKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // The absolute path is grepped by the capture script.
  debugPrint('SCREENSHOT_WRITTEN: ${file.path}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture desktop screenshots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final settings = await SettingsService.load();
    final notifications = NotificationService(); // not initialized: no prompt
    await tester.pumpWidget(RepaintBoundary(
      key: _rootKey,
      child: MailCrabApp(settings: settings, notifications: notifications),
    ));
    await settle(tester, const Duration(seconds: 2));
    await pumpUntil(tester, find.textContaining('Welcome to Acme'));

    final context = tester.element(find.byType(HomePage));
    final bloc = context.read<MailboxBloc>();
    void setTheme(String mode) => bloc.add(
        MailboxSettingsUpdated(bloc.state.settings.copyWith(themeMode: mode)));

    setTheme('light');
    await settle(tester);
    await tester.tap(find.textContaining('Welcome to Acme').first);
    await settle(tester, const Duration(seconds: 3));
    await capture('desktop-detail-light');

    setTheme('dark');
    await settle(tester, const Duration(seconds: 2));
    await capture('desktop-detail-dark');

    setTheme('system');
    await settle(tester);
  });
}
