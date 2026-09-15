import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Choix d'apparence de l'app. "custom" suit la luminosité du système
/// (clair/sombre automatique) mais avec une couleur d'accent au choix au
/// lieu de la couleur par défaut.
enum AppThemeChoice { light, dark, custom }

/// Réglages globaux de l'app (clés API, préférences).
class AppSettingsStore {
  static const String _boxName = 'app_settings';
  static late Box _box;

  static Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);

    themeChoiceNotifier.value = _readThemeChoice();
    accentColorNotifier.value = _readAccentColor();
  }

  // ─────────────────────────────────────────────
  // APPARENCE (clair / sombre / personnalisé)
  // ─────────────────────────────────────────────
  static final ValueNotifier<AppThemeChoice> themeChoiceNotifier =
      ValueNotifier(AppThemeChoice.light);
  static final ValueNotifier<Color?> accentColorNotifier = ValueNotifier(null);

  static AppThemeChoice _readThemeChoice() {
    switch (_box.get('themeChoice') as String?) {
      case 'dark':
        return AppThemeChoice.dark;
      case 'custom':
        return AppThemeChoice.custom;
      default:
        return AppThemeChoice.light;
    }
  }

  static AppThemeChoice get themeChoice => themeChoiceNotifier.value;

  static void setThemeChoice(AppThemeChoice choice) {
    _box.put('themeChoice', choice.name);
    themeChoiceNotifier.value = choice;
  }

  static Color? _readAccentColor() {
    final value = _box.get('accentColorValue') as int?;
    return value == null ? null : Color(value);
  }

  static Color? get accentColor => accentColorNotifier.value;

  static void setAccentColor(Color color) {
    _box.put('accentColorValue', color.toARGB32());
    accentColorNotifier.value = color;
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

  static bool get hasSeenWelcome =>
      _box.get('hasSeenWelcome') as bool? ?? false;

  static void setHasSeenWelcome(bool value) {
    _box.put('hasSeenWelcome', value);
  }

  /// Blocs optionnels du dashboard activés par l'utilisateur, dans l'ordre
  /// d'affichage choisi. Préférence d'affichage propre à cet appareil (pas
  /// une donnée financière) : reste locale, n'est pas synchronisée.
  static const List<String> _defaultDashboardBlocks = ['alert', 'recurring'];

  static List<String> get dashboardBlocks {
    final raw = _box.get('dashboardBlocks');
    if (raw == null) return List.of(_defaultDashboardBlocks);
    return List<String>.from(raw as List);
  }

  static void setDashboardBlocks(List<String> blocks) {
    _box.put('dashboardBlocks', blocks);
  }

  /// Supports masqués sur le dashboard (liste "Supports"). Un support non
  /// listé ici reste visible par défaut — préférence locale à l'appareil.
  static Set<String> get dashboardHiddenContainerIds {
    final raw = _box.get('dashboardHiddenContainerIds');
    if (raw == null) return {};
    return Set<String>.from(raw as List);
  }

  static void setDashboardHiddenContainerIds(Set<String> ids) {
    _box.put('dashboardHiddenContainerIds', ids.toList());
  }

  /// Mini-tuto du dashboard : affiché une seule fois, à la toute première
  /// arrivée sur le dashboard (juste après la création du premier compte),
  /// jamais liée à la création d'un support en particulier.
  static bool get hasSeenDashboardTutorial =>
      _box.get('hasSeenDashboardTutorial') as bool? ?? false;

  static void setHasSeenDashboardTutorial(bool value) {
    _box.put('hasSeenDashboardTutorial', value);
  }
}
