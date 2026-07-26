import 'package:hive/hive.dart';

import 'package:stability/core/finance/transactions_store.dart';
import 'package:stability/core/finance/transaction_type.dart';

/// Stocke les allocations (enveloppes) du budget base zéro :
/// - le montant alloué par catégorie et par mois
/// - le report ("carry-in") venant du solde restant du mois précédent
/// - le revenu prévisionnel saisi manuellement par mois
///
/// Le "dépensé" n'est jamais stocké ici : il est recalculé à la volée
/// depuis TransactionsStore, comme le fait déjà MonthlyBalancesStore
/// pour les soldes de conteneurs.
class CategoryAllocationsStore {
  static const String _boxName = 'category_allocations';
  static late Box _box;

  static Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  // ─────────────────────────────────────────────
  // CLÉS INTERNES
  // ─────────────────────────────────────────────
  static String _allocKey(String monthKey, String categoryId) =>
      'alloc::$monthKey::$categoryId';

  static String _carryKey(String monthKey, String categoryId) =>
      'carry::$monthKey::$categoryId';

  static String _incomeKey(String monthKey) => 'income::$monthKey';

  // ─────────────────────────────────────────────
  // ALLOCATION MANUELLE DU MOIS
  // ─────────────────────────────────────────────
  static double getAllocated(String monthKey, String categoryId) {
    if (!_box.isOpen) return 0.0;
    return (_box.get(_allocKey(monthKey, categoryId)) ?? 0.0).toDouble();
  }

  static void setAllocated(String monthKey, String categoryId, double value) {
    if (!_box.isOpen) return;
    _box.put(_allocKey(monthKey, categoryId), value);
  }

  // ─────────────────────────────────────────────
  // REPORT DU MOIS PRÉCÉDENT (écrit uniquement à la clôture)
  // ─────────────────────────────────────────────
  static double getCarryIn(String monthKey, String categoryId) {
    if (!_box.isOpen) return 0.0;
    return (_box.get(_carryKey(monthKey, categoryId)) ?? 0.0).toDouble();
  }

  static void _setCarryIn(String monthKey, String categoryId, double value) {
    if (!_box.isOpen) return;
    _box.put(_carryKey(monthKey, categoryId), value);
  }

  // ─────────────────────────────────────────────
  // REVENU PRÉVISIONNEL DU MOIS (saisi manuellement)
  // ─────────────────────────────────────────────
  static double getPlannedIncome(String monthKey) {
    if (!_box.isOpen) return 0.0;
    return (_box.get(_incomeKey(monthKey)) ?? 0.0).toDouble();
  }

  static void setPlannedIncome(String monthKey, double value) {
    if (!_box.isOpen) return;
    _box.put(_incomeKey(monthKey), value);
  }

  // ─────────────────────────────────────────────
  // DÉPENSÉ (calculé, jamais stocké)
  // Les transferts entre conteneurs ne comptent pas comme une dépense.
  // ─────────────────────────────────────────────
  static double spentForCategory(String monthKey, String categoryId) {
    return TransactionsStore.transactionsForMonth(monthKey)
        .where((t) =>
            t.category == categoryId &&
            t.type == TransactionType.expense &&
            t.transferId == null)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  // ─────────────────────────────────────────────
  // MONTANT DISPONIBLE DANS L'ENVELOPPE CE MOIS-CI
  // ─────────────────────────────────────────────
  static double available(String monthKey, String categoryId) {
    return getCarryIn(monthKey, categoryId) + getAllocated(monthKey, categoryId);
  }

  static double remaining(String monthKey, String categoryId) {
    return available(monthKey, categoryId) - spentForCategory(monthKey, categoryId);
  }

  // ─────────────────────────────────────────────
  // RESTE À ALLOUER (chaque euro doit avoir une mission)
  // ─────────────────────────────────────────────
  static double readyToAssign(String monthKey, List<String> categoryIds) {
    final totalAllocated = categoryIds.fold<double>(
      0,
      (sum, id) => sum + getAllocated(monthKey, id),
    );
    return getPlannedIncome(monthKey) - totalAllocated;
  }

  // ─────────────────────────────────────────────
  // CLÔTURE DE MOIS : report du restant de chaque enveloppe
  // (positif ou négatif) vers le mois suivant.
  // ─────────────────────────────────────────────
  static void closeMonth({
    required String monthKey,
    required String nextMonthKey,
    required List<String> categoryIds,
  }) {
    for (final categoryId in categoryIds) {
      final leftover = remaining(monthKey, categoryId);
      _setCarryIn(nextMonthKey, categoryId, leftover);
    }
  }

  // ─────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    if (!_box.isOpen) return;
    await _box.clear();
  }
}
