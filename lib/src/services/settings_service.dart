import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends Equatable {
  static const defaultSeedColor = 0xFFE4572E;

  final String serverUrl;

  final String authCookie;
  final bool notificationsEnabled;

  final String themeMode;

  final int seedColor;

  const AppSettings({
    this.serverUrl = 'http://localhost:1080',
    this.authCookie = '',
    this.notificationsEnabled = true,
    this.themeMode = 'system',
    this.seedColor = defaultSeedColor,
  });

  AppSettings copyWith({
    String? serverUrl,
    String? authCookie,
    bool? notificationsEnabled,
    String? themeMode,
    int? seedColor,
  }) =>
      AppSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        authCookie: authCookie ?? this.authCookie,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
      );

  @override
  List<Object?> get props =>
      [serverUrl, authCookie, notificationsEnabled, themeMode, seedColor];
}

class SettingsService {
  static const _kServerUrl = 'server_url';
  static const _kAuthCookie = 'auth_cookie';
  static const _kNotifications = 'notifications_enabled';
  static const _kThemeMode = 'theme_mode';
  static const _kSeedColor = 'seed_color';

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        serverUrl: prefs.getString(_kServerUrl) ?? 'http://localhost:1080',
        authCookie: prefs.getString(_kAuthCookie) ?? '',
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
      await prefs.setString(_kAuthCookie, settings.authCookie);
      await prefs.setBool(_kNotifications, settings.notificationsEnabled);
      await prefs.setString(_kThemeMode, settings.themeMode);
      await prefs.setInt(_kSeedColor, settings.seedColor);
    } catch (_) {
    }
  }
}
