import '../../accounts/current_account.dart';
import '../containers/container_model.dart';
import '../containers/container_type.dart';
import '../containers/containers_store.dart';
import '../finance/transaction.dart';
import '../finance/transaction_type.dart';
import '../finance/transactions_store.dart';
import 'category_allocations_store.dart';

/// Automatisation du virement "paie-toi en premier" (mode
/// [ManagementMode.payYourselfFirst]) et outils partagés liés aux virements
/// automatiques (réduction du capital restant dû d'un crédit, pointage).
///
/// L'automatisation par catégorie ("support de destination" + "Lancer le
/// budget du mois") a été retirée : les transactions récurrentes
/// (`RecurringTransactionsStore`) couvrent désormais ce besoin de façon
/// unifiée, sans dépendre d'une allocation de budget saisie à part.
class BudgetAutomationService {
  /// Réduit le capital restant dû d'un support "Crédit" quand un virement
  /// (manuel ou récurrent) y dépose de l'argent — le modèle crédit ne suit
  /// pas de solde par transaction, contrairement aux comptes classiques,
  /// donc ce réajustement doit être déclenché explicitement à chaque
  /// virement entrant plutôt que dérivé automatiquement.
  static Future<void> applyCreditRepayment(
    ContainersStore containersStore,
    String? containerId,
    double amount,
  ) async {
    if (containerId == null) return;

    ContainerModel? target;
    for (final c in containersStore.all) {
      if (c.id == containerId) {
        target = c;
        break;
      }
    }
    if (target == null || target.type != ContainerType.credit) return;

    final currentRemaining = target.creditRemainingBalance ?? 0;
    final newRemaining =
        (currentRemaining - amount) < 0 ? 0.0 : currentRemaining - amount;
    await containersStore.updateContainer(
      target.copyWith(creditRemainingBalance: newRemaining),
    );
  }

  // ─────────────────────────────────────────────
  // PAIE-TOI EN PREMIER (mode payYourselfFirst)
  // Indépendant des rubriques : un seul virement, pourcentage du revenu
  // prévisionnel vers un support d'épargne dédié.
  // ─────────────────────────────────────────────

  static String payYourselfFirstTransferId(String monthKey) =>
      'budgetrun_${monthKey}_pyf';

  static bool isPayYourselfFirstLaunched(String monthKey) {
    return TransactionsStore.all
        .any((t) => t.id == '${payYourselfFirstTransferId(monthKey)}_out');
  }

  /// Montant à épargner ce mois-ci selon le % configuré sur le compte et
  /// le revenu prévisionnel du mois. 0 si non configuré.
  static double payYourselfFirstAmount(String monthKey) {
    final percent = CurrentAccount.active.payYourselfFirstPercent;
    if (percent == null || percent <= 0) return 0;
    final income = CategoryAllocationsStore.getPlannedIncome(monthKey);
    return income * percent;
  }

  static Future<void> launchPayYourselfFirst({
    required String monthKey,
    required String sourceContainerId,
    required double amount,
  }) async {
    final destination = CurrentAccount.active.payYourselfFirstContainerId;
    if (destination == null || amount <= 0) return;
    if (isPayYourselfFirstLaunched(monthKey)) return;

    final transferId = payYourselfFirstTransferId(monthKey);
    const label = 'Paie-toi en premier';

    await TransactionsStore.add(
      Transaction(
        id: '${transferId}_out',
        label: label,
        amount: amount,
        date: DateTime.now(),
        type: TransactionType.expense,
        containerId: sourceContainerId,
        transferId: transferId,
        monthKey: monthKey,
      ),
    );
    await TransactionsStore.add(
      Transaction(
        id: '${transferId}_in',
        label: label,
        amount: amount,
        date: DateTime.now(),
        type: TransactionType.income,
        containerId: destination,
        transferId: transferId,
        monthKey: monthKey,
      ),
    );
  }

  /// Marque comme pointés tous les virements "paie-toi en premier" de ce
  /// mois pas encore validés.
  static Future<int> validateTransfers(
    String monthKey,
    ContainersStore containersStore,
  ) async {
    final prefix = 'budgetrun_$monthKey';
    var count = 0;
    for (final t in TransactionsStore.all) {
      if (t.id.startsWith(prefix) && !t.isCleared) {
        await TransactionsStore.setCleared(t.id, true);
        count++;

        if (t.type == TransactionType.income) {
          await applyCreditRepayment(containersStore, t.containerId, t.amount);
        }
      }
    }
    return count;
  }
}
