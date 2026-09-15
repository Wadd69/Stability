import '../containers/container_type.dart';
import '../containers/containers_store.dart';
import 'transaction.dart';
import 'transaction_type.dart';

/// Détermine si une transaction doit compter comme une vraie
/// dépense/rentrée dans les analyses agrégées (camembert, récap du mois,
/// archives, graphiques annuels) — par opposition aux calculs de solde
/// par support, qui doivent eux traiter chaque virement normalement.
///
/// Principe : un virement entre deux supports ne représente pas un gain
/// ou une perte réelle, juste un déplacement d'argent — il est donc
/// neutre par défaut (ni dépense, ni rentrée). Exception : un virement
/// dont la destination est un support "Crédit" représente un vrai
/// remboursement, donc une vraie sortie d'argent ce mois-ci — son côté
/// sortant compte comme une dépense (son côté entrant reste exclu, ce
/// n'est pas un revenu pour autant).
class TransactionAnalysis {
  /// Vrai si [t] est le côté sortant d'un virement dont au moins une des
  /// destinations (côté entrant, même `transferId`) est un support de
  /// type Crédit. [allTransactions] doit inclure les deux côtés du
  /// virement (source et destination) pour que la recherche fonctionne —
  /// en pratique la liste complète passée par l'écran appelant convient,
  /// les deux côtés d'un virement partageant toujours le même mois.
  static bool _isCreditRepaymentLeg(
    Transaction t,
    List<Transaction> allTransactions,
    ContainersStore containersStore,
  ) {
    final transferId = t.transferId;
    if (transferId == null) return false;

    final destinations = allTransactions.where(
      (o) => o.transferId == transferId && o.type == TransactionType.income,
    );

    for (final d in destinations) {
      final container = containersStore.all.where((c) => c.id == d.containerId);
      if (container.isNotEmpty &&
          container.first.type == ContainerType.credit) {
        return true;
      }
    }
    return false;
  }

  /// Vrai si [t] doit être comptée comme une dépense réelle dans les
  /// analyses agrégées.
  static bool countsAsExpense(
    Transaction t,
    List<Transaction> allTransactions,
    ContainersStore containersStore,
  ) {
    if (t.type != TransactionType.expense) return false;
    if (t.transferId == null) return true;
    return _isCreditRepaymentLeg(t, allTransactions, containersStore);
  }

  /// Vrai si [t] doit être comptée comme une rentrée d'argent réelle dans
  /// les analyses agrégées — jamais un virement, même un remboursement
  /// de crédit (la baisse de dette n'est pas un revenu).
  static bool countsAsIncome(Transaction t) {
    return t.type == TransactionType.income && t.transferId == null;
  }

  /// Filtre une liste de transactions pour ne garder que celles à
  /// prendre en compte dans une analyse agrégée (camembert, graphiques,
  /// récap) — pratique à appliquer avant de construire un widget de
  /// visualisation, en plus des filtres propres à l'écran (période,
  /// catégories sélectionnées, etc.). [transactions] sert aussi de base
  /// de recherche pour retrouver les paires de virement — donner la
  /// liste complète de la période analysée, pas une liste déjà filtrée
  /// par catégorie.
  static List<Transaction> filterForAnalysis(
    List<Transaction> transactions,
    ContainersStore containersStore,
  ) {
    return transactions
        .where((t) =>
            countsAsExpense(t, transactions, containersStore) ||
            countsAsIncome(t))
        .toList();
  }
}
