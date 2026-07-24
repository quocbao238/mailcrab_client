import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends Equatable {
  static const defaultSeedColor = 0xFFE4572E; // MailCrab crab orange

  /// Base URL of the MailCrab web server, e.g. `http://localhost:1080`
  /// (a path prefix is supported: `http://host:1080/mailcrab`).
  final String serverUrl;
  final bool notificationsEnabled;

  /// 'system' | 'light' | 'dark'
  final String themeMode;

  /// ARGB seed color for the Material color scheme.
  final int seedColor;

  const AppSettings({
    this.serverUrl = 'http://localhost:1080',
    this.notificationsEnabled = true,
    this.themeMode = 'system',
    this.seedColor = defaultSeedColor,
  });

  AppSettings copyWith({
    String? serverUrl,
    bool? notificationsEnabled,
    String? themeMode,
    int? seedColor,
  }) =>
      AppSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
      );

  @override
  List<Object?> get props =>
      [serverUrl, notificationsEnabled, themeMode, seedColor];
}

/// Persists settings to platform-local storage via shared_preferences
/// (Windows: %APPDATA%, macOS: NSUserDefaults, Linux: XDG data dir).
class SettingsService {
  static const _kServerUrl = 'server_url';
  static const _kNotifications = 'notifications_enabled';
  static const _kThemeMode = 'theme_mode';
  static const _kSeedColor = 'seed_color';

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        serverUrl: prefs.getString(_kServerUrl) ?? 'http://localhost:1080',
        notificationsEnabled: prefs.getBool(_kNotifications) ?? true,
        themeMode: prefs.getString(_kThemeMode) ?? 'system',
        seedColor:
            prefs.getInt(_kSeedColor) ?? AppSettings.defaultSeedColor,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServerUrl, settings.serverUrl);
      await prefs.setBool(_kNotifications, settings.notificationsEnabled);
      await prefs.setString(_kThemeMode, settings.themeMode);
      await prefs.setInt(_kSeedColor, settings.seedColor);
    } catch (_) {
      // Persisting settings is best-effort; the in-memory value still applies.
    }
  }
}
