import 'account.dart';
import 'management_mode.dart';

class AccountsRepository {
  static final List<Account> accounts = [
    const Account(
      id: 'perso',
      name: 'Compte personnel',
      isShared: false,
      managementMode: ManagementMode.zeroBudget,
    ),
    const Account(
      id: 'commun',
      name: 'Compte commun',
      isShared: true,
      managementMode: ManagementMode.fiftyThirtyTwenty,
    ),
  ];
}
