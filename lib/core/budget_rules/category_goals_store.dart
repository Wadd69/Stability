import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stability/accounts/current_account.dart';

/// Objectif d'épargne optionnel pour une catégorie (ex: "Vacances : 600€").
/// La progression n'est jamais stockée ici : elle correspond au solde
/// courant de l'enveloppe (CategoryAllocationsStore.remaining), qui
/// s'accumule mois après mois tant qu'il n'est pas dépensé.
///
/// Stocké sur Supabase (table `category_goals`), scopé par compte.
class CategoryGoalsStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final Map<String, double> _goals = {};

  static Future<void> init() async {
    _goals.clear();

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    final rows =
        await _client.from('category_goals').select().eq('account_id', accountId);

    for (final r in (rows as List)) {
      final row = r as Map<String, dynamic>;
      _goals[row['category_id'] as String] = (row['amount'] as num).toDouble();
    }
  }

  static double? getGoal(String categoryId) => _goals[categoryId];

  static Future<void> setGoal(String categoryId, double? amount) async {
    final accountId = CurrentAccount.active.id;

    if (amount == null || amount <= 0) {
      _goals.remove(categoryId);
      if (accountId.isEmpty) return;
      await _client
          .from('category_goals')
          .delete()
          .eq('account_id', accountId)
          .eq('category_id', categoryId);
    } else {
      _goals[categoryId] = amount;
      if (accountId.isEmpty) return;
      await _client.from('category_goals').upsert({
        'account_id': accountId,
        'category_id': categoryId,
        'amount': amount,
      });
    }
  }

  static Future<void> clearAll() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client.from('category_goals').delete().eq('account_id', accountId);
    }
    _goals.clear();
  }
}
