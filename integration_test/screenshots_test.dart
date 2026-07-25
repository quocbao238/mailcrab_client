// Captures marketing screenshots against a live local MailCrab server.
//
// Run (with MailCrab on localhost:1080 seeded with demo mail):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart \
//     --dart-define=SCREENSHOT_MODE=true -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mailcrab_client/main.dart' as app;
import 'package:mailcrab_client/src/bloc/mailbox_bloc.dart';
import 'package:mailcrab_client/src/ui/home_page.dart';

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
  // pumpAndSettle never finishes (live status animation) — pump frames instead.
  final frames = duration.inMilliseconds ~/ 50;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture screenshots', (tester) async {
    await app.main();
    await settle(tester, const Duration(seconds: 2));

    // Wait for the demo inbox to load from the local server.
    await pumpUntil(tester, find.textContaining('Welcome to Acme'));

    final context = tester.element(find.byType(HomePage));
    final bloc = context.read<MailboxBloc>();
    final wide = MediaQuery.of(context).size.width >= 760;
    final device = wide ? 'tablet' : 'phone';

    void setTheme(String mode) => bloc.add(
        MailboxSettingsUpdated(bloc.state.settings.copyWith(themeMode: mode)));

    setTheme('light');
    await settle(tester);

    if (!wide) {
      // Narrow layout: capture the list alone first.
      await binding.takeScreenshot('$device-list-light');
    }

    // Open the welcome mail (renders a nice HTML body).
    await tester.tap(find.textContaining('Welcome to Acme').first);
    await settle(tester, const Duration(seconds: 3));
    await binding.takeScreenshot('$device-detail-light');

    setTheme('dark');
    await settle(tester, const Duration(seconds: 2));
    await binding.takeScreenshot('$device-detail-dark');

    if (!wide) {
      final back = find.byType(BackButton);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await settle(tester);
      }
      await binding.takeScreenshot('$device-list-dark');
    }

    setTheme('system');
    await settle(tester);
  });
}
