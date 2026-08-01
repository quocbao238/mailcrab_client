import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';

enum NotificationPermissionStatus {
  granted,
  denied,

  unknown,
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String messageId)? onSelectMessage;

  bool _available = false;

  Future<void> init() async {
    if (kIsWeb) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
        appName: 'MailCrab Client',
        appUserModelId: 'net.fastboy.mailcrab',
        guid: 'a3f1e2d4-5b6c-4d7e-8f90-1a2b3c4d5e6f',
      ),
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final id = response.payload;
          if (id != null && id.isNotEmpty) {
            onSelectMessage?.call(id);
          }
        },
      );
      await _requestPermissions();
      _available = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> _requestPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      case TargetPlatform.iOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      case TargetPlatform.android:
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      default:
        break;
    }
  }

  Future<NotificationPermissionStatus> checkPermission() async {
    if (kIsWeb) return NotificationPermissionStatus.unknown;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
          if (options == null) return NotificationPermissionStatus.unknown;
          return options.isEnabled
              ? NotificationPermissionStatus.granted
              : NotificationPermissionStatus.denied;
        case TargetPlatform.iOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
          if (options == null) return NotificationPermissionStatus.unknown;
          return options.isEnabled
              ? NotificationPermissionStatus.granted
              : NotificationPermissionStatus.denied;
        case TargetPlatform.android:
          final enabled = await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled();
          if (enabled == null) return NotificationPermissionStatus.unknown;
          return enabled
              ? NotificationPermissionStatus.granted
              : NotificationPermissionStatus.denied;
        default:
          return NotificationPermissionStatus.unknown;
      }
    } catch (e) {
      debugPrint('checkPermission failed: $e');
      return NotificationPermissionStatus.unknown;
    }
  }

  Future<NotificationPermissionStatus> requestPermission() async {
    if (kIsWeb) return NotificationPermissionStatus.unknown;
    try {
      await _requestPermissions();
      _available = true;
    } catch (e) {
      debugPrint('requestPermission failed: $e');
    }
    return checkPermission();
  }

  Future<void> showNewMail(MailMessageMetadata meta, {String? snippet}) async {
    if (!_available) {
      debugPrint('Notification skipped (plugin not initialized): '
          '${meta.displaySubject}');
      return;
    }
    debugPrint('Posting notification: ${meta.displaySubject}');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_mail',
        'New mail',
        channelDescription: 'Notifications for new emails received by MailCrab',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );

    final sender =
        meta.from.short == '(unknown)' ? meta.envelopeFrom : meta.from.short;
    final body = (snippet == null || snippet.isEmpty)
        ? meta.displaySubject
        : '${meta.displaySubject}\n$snippet';

    try {
      await _plugin.show(
        id: meta.id.hashCode,
        title: 'New mail from $sender',
        body: body,
        notificationDetails: details,
        payload: meta.id,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
