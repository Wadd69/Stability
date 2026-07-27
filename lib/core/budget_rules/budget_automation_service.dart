import '../../accounts/current_account.dart';
import '../../accounts/management_mode.dart';
import '../containers/container_model.dart';
import '../containers/containers_store.dart';
import '../finance/budget_bucket.dart';
import '../finance/categories_store.dart';
import '../finance/transaction.dart';
import '../finance/transaction_type.dart';
import '../finance/transactions_store.dart';
import 'category_allocations_store.dart';
import 'category_goals_store.dart';

/// Une catégorie éligible à l'automatisation du budget du mois, avec le
/// montant calculé selon le mode de gestion actif.
class EligibleCategory {
  final Category category;
  final double amount;

  EligibleCategory({required this.category, required this.amount});
}

/// Un groupe de catégories partageant le même support de destination :
/// donne lieu à un seul virement réel, détaillé par catégorie.
class DestinationGroup {
  final String targetContainerId;
  final List<EligibleCategory> categories;

  DestinationGroup({required this.targetContainerId, required this.categories});

  double get total => categories.fold<double>(0, (s, c) => s + c.amount);
}

/// Génère les virements automatiques du "budget du mois" : pour chaque
/// catégorie ayant un support de destination configuré (voir
/// `Category.targetContainerId`), calcule le montant à virer selon le mode
/// de gestion actif, regroupe par destination, et crée un virement unique
/// par destination (scindé par catégorie si plusieurs catégories y
/// contribuent). Fonctionne dans tous les modes de gestion ; en mode
/// personnalisé, aucun montant n'est calculable (le mode lui-même n'est
/// pas encore implémenté ailleurs dans l'app).
class BudgetAutomationService {
  /// Montant que cette catégorie doit recevoir ce mois-ci, selon le mode
  /// de gestion actif du compte courant. 0 si le mode ne définit rien pour
  /// cette catégorie (ex: pas de bucket en 50/30/20, pas d'objectif en
  /// mode libre).
  static double plannedAmountForCategory(String monthKey, Category category) {
    switch (CurrentAccount.active.managementMode) {
      case ManagementMode.zeroBudget:
        return CategoryAllocationsStore.getAllocated(monthKey, category.id);

      case ManagementMode.fiftyThirtyTwenty:
        if (category.bucket == null) return 0;
        final income = CategoryAllocationsStore.getPlannedIncome(monthKey);
        final bucketTarget = income * category.bucket!.targetShare;

        final peers = CategoriesStore.all
            .where((c) =>
                c.bucket == category.bucket && c.targetContainerId != null)
            .toList();
        if (peers.isEmpty) return 0;

        // Pondération par objectif d'épargne s'il existe, sinon répartition
        // égale entre les catégories du même bucket.
        final weights = {
          for (final c in peers) c.id: CategoryGoalsStore.getGoal(c.id) ?? 1.0,
        };
        final totalWeight = weights.values.fold<double>(0, (a, b) => a + b);
        if (totalWeight <= 0) return 0;
        return bucketTarget * ((weights[category.id] ?? 0) / totalWeight);

      case ManagementMode.free:
        return CategoryGoalsStore.getGoal(category.id) ?? 0;

      case ManagementMode.custom:
        // Le mode personnalisé n'est pas encore implémenté ailleurs dans
        // l'app (CustomModePlaceholderScreen) : pas de moteur à inventer
        // ici, aucune catégorie n'y sera jamais éligible.
        return 0;
    }
  }

  static ContainerModel? _findTarget(
    ContainersStore containersStore,
    String? id,
  ) {
    if (id == null) return null;
    for (final c in containersStore.all) {
      if (c.id == id && !c.isArchived) return c;
    }
    return null;
  }

  /// Catégories éligibles ce mois-ci : support de destination configuré
  /// (non archivé) et montant calculé strictement positif.
  static List<EligibleCategory> eligibleCategories(
    String monthKey,
    ContainersStore containersStore,
  ) {
    final result = <EligibleCategory>[];
    for (final category in CategoriesStore.all) {
      final target = _findTarget(containersStore, category.targetContainerId);
      if (target == null) continue;

      final amount = plannedAmountForCategory(monthKey, category);
      if (amount <= 0) continue;

      result.add(EligibleCategory(category: category, amount: amount));
    }
    return result;
  }

  static List<DestinationGroup> groupByDestination(
    List<EligibleCategory> eligible,
  ) {
    final map = <String, List<EligibleCategory>>{};
    for (final e in eligible) {
      map.putIfAbsent(e.category.targetContainerId!, () => []).add(e);
    }
    return map.entries
        .map((e) => DestinationGroup(targetContainerId: e.key, categories: e.value))
        .toList();
  }

  static String transferIdFor(String monthKey, String targetContainerId) =>
      'budgetrun_${monthKey}_$targetContainerId';

  static bool isAlreadyLaunched(String monthKey, String targetContainerId) {
    final id = transferIdFor(monthKey, targetContainerId);
    return TransactionsStore.all.any((t) => t.id == '${id}_out');
  }

  /// Crée les virements groupés pour les groupes fournis. Idempotent : un
  /// groupe déjà lancé ce mois-ci (même destination) est ignoré.
  static void launchMonth({
    required String monthKey,
    required String sourceContainerId,
    required List<DestinationGroup> groups,
  }) {
    const label = 'Budget du mois';

    for (final group in groups) {
      if (isAlreadyLaunched(monthKey, group.targetContainerId)) continue;

      final transferId = transferIdFor(monthKey, group.targetContainerId);

      if (group.categories.length == 1) {
        final only = group.categories.first;
        TransactionsStore.add(
          Transaction(
            id: '${transferId}_out',
            label: label,
            amount: only.amount,
            date: DateTime.now(),
            type: TransactionType.expense,
            category: only.category.id,
            containerId: sourceContainerId,
            transferId: transferId,
            monthKey: monthKey,
          ),
        );
        TransactionsStore.add(
          Transaction(
            id: '${transferId}_in',
            label: label,
            amount: only.amount,
            date: DateTime.now(),
            type: TransactionType.income,
            category: only.category.id,
            containerId: group.targetContainerId,
            transferId: transferId,
            monthKey: monthKey,
          ),
        );
      } else {
        TransactionsStore.add(
          Transaction(
            id: '${transferId}_out',
            label: label,
            amount: group.total,
            date: DateTime.now(),
            type: TransactionType.expense,
            containerId: sourceContainerId,
            transferId: transferId,
            monthKey: monthKey,
          ),
        );

        final dstSplitGroupId = '${transferId}_dst';
        for (int j = 0; j < group.categories.length; j++) {
          final ec = group.categories[j];
          TransactionsStore.add(
            Transaction(
              id: '${transferId}_in_$j',
              label: label,
              amount: ec.amount,
              date: DateTime.now(),
              type: TransactionType.income,
              category: ec.category.id,
              containerId: group.targetContainerId,
              transferId: transferId,
              splitGroupId: dstSplitGroupId,
              monthKey: monthKey,
            ),
          );
        }
      }
    }
  }

  /// Marque comme pointés tous les virements "budget du mois" de ce mois
  /// pas encore validés individuellement. Retourne le nombre de lignes
  /// mises à jour.
  static int validateTransfers(String monthKey) {
    final prefix = 'budgetrun_$monthKey';
    var count = 0;
    for (final t in TransactionsStore.all) {
      if (t.id.startsWith(prefix) && !t.isCleared) {
        TransactionsStore.setCleared(t.id, true);
        count++;
      }
    }
    return count;
  }

  /// Vrai s'il existe au moins un virement "budget du mois" non pointé
  /// pour ce mois (utilisé pour n'afficher "Valider les virements" que
  /// quand c'est pertinent).
  static bool hasPendingTransfers(String monthKey) {
    final prefix = 'budgetrun_$monthKey';
    return TransactionsStore.all
        .any((t) => t.id.startsWith(prefix) && !t.isCleared);
  }
}
