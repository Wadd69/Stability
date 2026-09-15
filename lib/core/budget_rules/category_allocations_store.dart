import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stability/accounts/current_account.dart';
import 'package:stability/core/finance/transactions_store.dart';
import 'package:stability/core/finance/transaction_type.dart';

/// Allocations (enveloppes) du budget base zéro : le montant alloué par
/// catégorie et par mois, le report ("carry-in") venant du solde restant
/// du mois précédent, et le revenu prévisionnel saisi manuellement par
/// mois. Stockées sur Supabase (tables `category_allocations` et
/// `planned_income`), scopées par compte.
///
/// Le "dépensé" n'est jamais stocké ici : il est recalculé à la volée
/// depuis TransactionsStore, comme le fait déjà MonthlyBalancesStore
/// pour les soldes de conteneurs.
class CategoryAllocationsStore {
  static SupabaseClient get _client => Supabase.instance.client;

  static final Map<String, double> _allocations = {};
  static final Map<String, double> _carryIns = {};
  static final Map<String, double> _plannedIncomes = {};

  static String _key(String monthKey, String categoryId) =>
      '$monthKey::$categoryId';

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    _allocations.clear();
    _carryIns.clear();
    _plannedIncomes.clear();

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    final allocRows = await _client
        .from('category_allocations')
        .select()
        .eq('account_id', accountId);

    for (final r in (allocRows as List)) {
      final row = r as Map<String, dynamic>;
      final key =
          _key(row['month_key'] as String, row['category_id'] as String);
      _allocations[key] = (row['allocated'] as num).toDouble();
      _carryIns[key] = (row['carry_in'] as num).toDouble();
    }

    final incomeRows = await _client
        .from('planned_income')
        .select()
        .eq('account_id', accountId);

    for (final r in (incomeRows as List)) {
      final row = r as Map<String, dynamic>;
      _plannedIncomes[row['month_key'] as String] =
          (row['amount'] as num).toDouble();
    }
  }

  // ─────────────────────────────────────────────
  // ALLOCATION MANUELLE DU MOIS
  // ─────────────────────────────────────────────
  static double getAllocated(String monthKey, String categoryId) {
    return _allocations[_key(monthKey, categoryId)] ?? 0.0;
  }

  static Future<void> setAllocated(
    String monthKey,
    String categoryId,
    double value,
  ) async {
    _allocations[_key(monthKey, categoryId)] = value;

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('category_allocations').upsert({
      'account_id': accountId,
      'month_key': monthKey,
      'category_id': categoryId,
      'allocated': value,
    });
  }

  // ─────────────────────────────────────────────
  // REPORT DU MOIS PRÉCÉDENT (écrit uniquement à la clôture)
  // ─────────────────────────────────────────────
  static double getCarryIn(String monthKey, String categoryId) {
    return _carryIns[_key(monthKey, categoryId)] ?? 0.0;
  }

  /// Distingue "jamais reporté" de "reporté à 0€" — sert de garde-fou
  /// d'idempotence (voir closeMonth).
  static bool hasCarryIn(String monthKey, String categoryId) {
    return _carryIns.containsKey(_key(monthKey, categoryId));
  }

  static Future<void> _setCarryIn(
    String monthKey,
    String categoryId,
    double value,
  ) async {
    _carryIns[_key(monthKey, categoryId)] = value;

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('category_allocations').upsert({
      'account_id': accountId,
      'month_key': monthKey,
      'category_id': categoryId,
      'carry_in': value,
    });
  }

  // ─────────────────────────────────────────────
  // REVENU PRÉVISIONNEL DU MOIS (saisi manuellement)
  // ─────────────────────────────────────────────
  static double getPlannedIncome(String monthKey) {
    return _plannedIncomes[monthKey] ?? 0.0;
  }

  static Future<void> setPlannedIncome(String monthKey, double value) async {
    _plannedIncomes[monthKey] = value;

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('planned_income').upsert({
      'account_id': accountId,
      'month_key': monthKey,
      'amount': value,
    });
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
    return getCarryIn(monthKey, categoryId) +
        getAllocated(monthKey, categoryId);
  }

  static double remaining(String monthKey, String categoryId) {
    return available(monthKey, categoryId) -
        spentForCategory(monthKey, categoryId);
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
  static Future<void> closeMonth({
    required String monthKey,
    required String nextMonthKey,
    required List<String> categoryIds,
  }) async {
    for (final categoryId in categoryIds) {
      // Garde-fou d'idempotence (même raison que MonthlyBalancesStore) :
      // un second passage verrait les transactions de monthKey déjà
      // archivées par TransactionsStore.closeMonth, donc "dépensé" à tort
      // proche de 0 — et écraserait le bon report par un mauvais.
      if (hasCarryIn(nextMonthKey, categoryId)) continue;

      final leftover = remaining(monthKey, categoryId);
      await _setCarryIn(nextMonthKey, categoryId, leftover);
    }
  }

  // ─────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client
          .from('category_allocations')
          .delete()
          .eq('account_id', accountId);
      await _client.from('planned_income').delete().eq('account_id', accountId);
    }
    _allocations.clear();
    _carryIns.clear();
    _plannedIncomes.clear();
  }
}
