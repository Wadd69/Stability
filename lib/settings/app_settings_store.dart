import 'package:hive/hive.dart';

/// Réglages globaux de l'app (clés API, préférences).
class AppSettingsStore {
  static const String _boxName = 'app_settings';
  static late Box _box;

  static Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  static String? get finnhubApiKey {
    final value = _box.get('finnhubApiKey') as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static void setFinnhubApiKey(String? key) {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _box.delete('finnhubApiKey');
    } else {
      _box.put('finnhubApiKey', trimmed);
    }
  }

  static String? get activeAccountId => _box.get('activeAccountId') as String?;

  static void setActiveAccountId(String id) {
    _box.put('activeAccountId', id);
  }

  static void clearActiveAccountId() {
    _box.delete('activeAccountId');
  }

  static bool get hasSeenWelcome => _box.get('hasSeenWelcome') as bool? ?? false;

  static void setHasSeenWelcome(bool value) {
    _box.put('hasSeenWelcome', value);
  }
}
