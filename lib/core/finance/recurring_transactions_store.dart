import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import 'recurring_transaction.dart';
import 'transaction.dart';
import 'transactions_store.dart';

/// Gabarits de transactions récurrentes du compte actif — stockés sur
/// Supabase (table `recurring_transactions`), scopés par `account_id`.
class RecurringTransactionsStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<RecurringTransaction> _items = [];

  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _items.clear();
      return;
    }

    final rows = await _client
        .from('recurring_transactions')
        .select()
        .eq('account_id', accountId);

    _items
      ..clear()
      ..addAll(
        (rows as List)
            .map((r) => RecurringTransaction.fromMap(r as Map<String, dynamic>)),
      );
  }

  static List<RecurringTransaction> get all => List.unmodifiable(_items);

  static Future<void> add(RecurringTransaction recurring) async {
    await _client.from('recurring_transactions').insert({
      ...recurring.toMap(),
      'account_id': CurrentAccount.active.id,
    });
    _items.add(recurring);
  }

  static Future<void> update(RecurringTransaction recurring) async {
    final index = _items.indexWhere((r) => r.id == recurring.id);
    if (index == -1) return;

    await _client
        .from('recurring_transactions')
        .update(recurring.toMap())
        .eq('id', recurring.id);
    _items[index] = recurring;
  }

  static Future<void> remove(String id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
    _items.removeWhere((r) => r.id == id);
  }

  static Future<void> setActive(String id, bool active) async {
    final index = _items.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final updated = _items[index].copyWith(active: active);
    await _client
        .from('recurring_transactions')
        .update({'active': active}).eq('id', id);
    _items[index] = updated;
  }

  static Future<void> clear() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client
          .from('recurring_transactions')
          .delete()
          .eq('account_id', accountId);
    }
    _items.clear();
  }

  // ─────────────────────────────────────────────
  // GÉNÉRATION
  // ─────────────────────────────────────────────

  static bool _isDue(RecurringTransaction r, String monthKey) {
    if (!r.active) return false;
    if (monthKey.compareTo(r.startMonthKey) < 0) return false;
    if (r.endMonthKey != null && monthKey.compareTo(r.endMonthKey!) > 0) {
      return false;
    }
    if (r.lastGeneratedMonthKey == monthKey) return false;

    if (r.frequency == RecurrenceFrequency.yearly) {
      final startMonth = int.parse(r.startMonthKey.split('-')[1]);
      final targetMonth = int.parse(monthKey.split('-')[1]);
      if (startMonth != targetMonth) return false;
    }

    return true;
  }

  /// Crée les transactions dues pour ce mois à partir des gabarits actifs.
  /// Idempotent : un gabarit déjà généré pour ce mois ne l'est pas deux fois.
  /// Retourne le nombre de transactions créées.
  static Future<int> generateDueForMonth(String monthKey) async {
    int count = 0;
    final updatedTemplates = <Map<String, dynamic>>[];

    for (int i = 0; i < _items.length; i++) {
      final r = _items[i];
      if (!_isDue(r, monthKey)) continue;

      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final day = r.dayOfMonth.clamp(1, lastDayOfMonth);

      await TransactionsStore.add(
        Transaction(
          id: 'recurring_${r.id}_$monthKey',
          label: r.label,
          amount: r.amount,
          date: DateTime(year, month, day),
          type: r.type,
          category: r.category,
          containerId: r.containerId,
          monthKey: monthKey,
        ),
      );

      final updated = r.copyWith(lastGeneratedMonthKey: monthKey);
      _items[i] = updated;
      updatedTemplates.add({
        ...updated.toMap(),
        'account_id': CurrentAccount.active.id,
      });
      count++;
    }

    if (updatedTemplates.isNotEmpty) {
      await _client.from('recurring_transactions').upsert(updatedTemplates);
    }

    return count;
  }
}
