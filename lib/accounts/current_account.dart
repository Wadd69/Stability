import '../backend/cloud_account.dart';
import '../settings/app_settings_store.dart';
import 'management_mode.dart';

class CurrentAccount {
  static CloudAccount? _active;

  static bool get hasActive => _active != null;

  /// Valeur de repli si aucun compte n'est encore chargé — ne devrait
  /// jamais être visible puisque AppRoot affiche un écran de chargement
  /// ou de création de compte tant qu'aucun compte n'est disponible.
  static CloudAccount get active =>
      _active ??
      const CloudAccount(
        id: '',
        name: '—',
        isShared: false,
        managementMode: ManagementMode.free,
        ownerId: '',
      );

  static set active(CloudAccount account) {
    _active = account;
    AppSettingsStore.setActiveAccountId(account.id);
  }

  /// À appeler après avoir récupéré la liste des comptes accessibles
  /// (voir AppRoot) pour restaurer le dernier compte utilisé, ou à
  /// défaut le premier disponible.
  static Future<void> restoreFromSettings(List<CloudAccount> available) async {
    final id = AppSettingsStore.activeAccountId;
    if (id != null) {
      final match = available.where((a) => a.id == id);
      if (match.isNotEmpty) {
        _active = match.first;
        return;
      }
    }

    if (available.isNotEmpty) {
      _active = available.first;
    } else {
      _active = null;
    }
  }

  static void clear() {
    _active = null;
    AppSettingsStore.clearActiveAccountId();
  }
}
