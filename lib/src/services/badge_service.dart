import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class BadgeService {
  static const _channel = MethodChannel('mailcrab/badge');

  int? _lastCount;

  Future<void> setCount(int count) async {
    if (kIsWeb) return;
    if (count == _lastCount) return;
    _lastCount = count;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          await _channel.invokeMethod<void>(
            'setBadge',
            count > 0 ? '$count' : '',
          );
        case TargetPlatform.windows:
          if (count <= 0) {
            await WindowsTaskbar.resetOverlayIcon();
          } else {
            final name = count > 9 ? '9plus' : '$count';
            await WindowsTaskbar.setOverlayIcon(
              ThumbnailToolbarAssetIcon('assets/badges/badge_$name.ico'),
              tooltip: '$count unread',
            );
          }
        default:
          break;
      }
    } catch (e) {
      debugPrint('App icon badge update failed: $e');
    }
  }
}
