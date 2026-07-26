import 'account.dart';
import 'accounts_repository.dart';
import 'management_mode.dart';
import '../settings/app_settings_store.dart';

class CurrentAccount {
  static Account _active = const Account(
    id: 'perso',
    name: 'Compte personnel',
    isShared: false,
    managementMode: ManagementMode.zeroBudget,
  );

  static Account get active => _active;

  static set active(Account account) {
    _active = account;
    AppSettingsStore.setActiveAccountId(account.id);
  }

  /// À appeler au démarrage (après AppSettingsStore.init()) pour
  /// restaurer le dernier compte utilisé.
  static void restoreFromSettings() {
    final id = AppSettingsStore.activeAccountId;
    if (id == null) return;

    final match =
        AccountsRepository.accounts.where((a) => a.id == id).toList();
    if (match.isNotEmpty) {
      _active = match.first;
    }
  }
}
