import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import 'archived_month.dart';

/// Résumés de mois archivés du compte actif — stockés sur Supabase (table
/// `archives`), scopés par `account_id`. Les transactions archivées
/// elles-mêmes vivent dans `TransactionsStore` (voir [ArchivedMonth]).
class ArchivesStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<ArchivedMonth> _months = [];

  // 🔹 INIT
  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _months.clear();
      return;
    }

    final rows =
        await _client.from('archives').select().eq('account_id', accountId);

    _months
      ..clear()
      ..addAll(
        (rows as List)
            .map((r) => ArchivedMonth.fromMap(r as Map<String, dynamic>)),
      );
  }

  // 🔹 Lecture
  static List<ArchivedMonth> get all => List.unmodifiable(_months);

  static List<int> get years =>
      _months.map((m) => m.year).toSet().toList()..sort();

  static List<ArchivedMonth> byYear(int year) {
    return _months.where((m) => m.year == year).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  /// 🔹 MOIS PRÉCÉDENT
  static ArchivedMonth? getPreviousMonth(int year, int month) {
    try {
      return _months
          .where((m) => m.year < year || (m.year == year && m.month < month))
          .reduce(
            (a, b) => (a.year * 12 + a.month) > (b.year * 12 + b.month) ? a : b,
          );
    } catch (_) {
      return null;
    }
  }

  // ➕ Ajouter / remplacer un mois archivé
  static Future<void> add(ArchivedMonth month) async {
    await _client.from('archives').upsert({
      ...month.toMap(),
      'account_id': CurrentAccount.active.id,
    });

    _months.removeWhere((m) => m.id == month.id);
    _months.add(month);
  }

  /// Création/mise à jour du résumé d'un mois archivé — les totaux sont
  /// déjà calculés par l'appelant (TransactionsStore.closeMonth).
  static Future<void> archiveMonth({
    required String monthKey,
    required String label,
    required double totalIncome,
    required double totalExpense,
    required double balance,
  }) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    await add(
      ArchivedMonth(
        id: monthKey,
        year: year,
        month: month,
        label: label,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        balance: balance,
      ),
    );
  }

  // 🔥 RESET DEV
  static Future<void> clear() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client.from('archives').delete().eq('account_id', accountId);
    }
    _months.clear();
  }
}
