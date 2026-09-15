import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import '../budget_rules/budget_automation_service.dart';
import '../containers/containers_store.dart';
import 'recurring_overrides_store.dart';
import 'recurring_transaction.dart';
import 'transaction.dart';
import 'transaction_type.dart';
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
        (rows as List).map(
            (r) => RecurringTransaction.fromMap(r as Map<String, dynamic>)),
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

  /// Nombre de mois entiers entre deux "YYYY-MM".
  static int _monthsBetween(String fromMonthKey, String toMonthKey) {
    final from = fromMonthKey.split('-');
    final to = toMonthKey.split('-');
    final fromYear = int.parse(from[0]);
    final fromMonth = int.parse(from[1]);
    final toYear = int.parse(to[0]);
    final toMonth = int.parse(to[1]);
    return (toYear - fromYear) * 12 + (toMonth - fromMonth);
  }

  /// Ajoute [months] mois à un "YYYY-MM".
  static String _addMonths(String monthKey, int months) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final total = (year * 12 + (month - 1)) + months;
    final newYear = total ~/ 12;
    final newMonth = (total % 12) + 1;
    return '$newYear-${newMonth.toString().padLeft(2, '0')}';
  }

  /// Prochaine date calendaire à laquelle [r] est due, à partir de [from]
  /// (aujourd'hui par défaut). Retourne `null` si le gabarit est inactif ou
  /// si sa date de fin est déjà passée — utilisé pour l'affichage du widget
  /// d'écran d'accueil ("ce qui reste à passer").
  static DateTime? nextOccurrence(RecurringTransaction r, {DateTime? from}) {
    if (!r.active) return null;

    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    var candidateMonthKey = r.startMonthKey.compareTo(nowMonthKey) > 0
        ? r.startMonthKey
        : nowMonthKey;

    final elapsed = _monthsBetween(r.startMonthKey, candidateMonthKey);
    final remainder = elapsed % r.frequency.intervalMonths;
    if (remainder != 0) {
      candidateMonthKey =
          _addMonths(candidateMonthKey, r.frequency.intervalMonths - remainder);
    }

    while (r.endMonthKey == null ||
        candidateMonthKey.compareTo(r.endMonthKey!) <= 0) {
      final parts = candidateMonthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final day = r.dayOfMonth.clamp(1, lastDayOfMonth);
      final date = DateTime(year, month, day);

      if (!date.isBefore(today)) return date;

      candidateMonthKey =
          _addMonths(candidateMonthKey, r.frequency.intervalMonths);
    }

    return null;
  }

  static bool _isDue(RecurringTransaction r, String monthKey) {
    if (!r.active) return false;
    if (monthKey.compareTo(r.startMonthKey) < 0) return false;
    if (r.endMonthKey != null && monthKey.compareTo(r.endMonthKey!) > 0) {
      return false;
    }
    if (r.lastGeneratedMonthKey == monthKey) return false;

    final elapsed = _monthsBetween(r.startMonthKey, monthKey);
    if (elapsed % r.frequency.intervalMonths != 0) return false;

    return true;
  }

  /// Crée les transactions dues pour ce mois à partir des gabarits actifs.
  /// Idempotent : un gabarit déjà généré pour ce mois ne l'est pas deux fois.
  /// Retourne le nombre de transactions créées.
  static Future<int> generateDueForMonth(
    String monthKey,
    ContainersStore containersStore,
  ) async {
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
      final date = DateTime(year, month, day);
      final id = 'recurring_${r.id}_$monthKey';
      // La date réelle (calendaire) reste dans le mois traité — seul le
      // "mois budgétaire" auquel la transaction est rattachée se décale,
      // si l'utilisateur l'a demandé (ex: salaire du 25 qui doit compter
      // pour le mois suivant). Le solde affiché de l'app peut donc
      // s'écarter temporairement du compte en banque réel jusqu'à la
      // clôture du mois suivant — c'est le compromis assumé par ce choix.
      final effectiveMonthKey =
          r.countsForNextMonth ? _addMonths(monthKey, 1) : monthKey;
      final legsForOverrideCheck = r.destinationLegs;
      final isSplitTransfer = r.type == TransactionType.transfer &&
          legsForOverrideCheck != null &&
          legsForOverrideCheck.isNotEmpty;
      final override = isSplitTransfer
          ? null
          : RecurringOverridesStore.getOverride(r.id, monthKey);
      final effectiveAmount = override ?? r.amount;
      if (override != null) {
        await RecurringOverridesStore.clearOverride(r.id, monthKey);
      }

      if (r.type == TransactionType.transfer) {
        if (r.containerId == null) continue;
        final legs = r.destinationLegs;
        if (legs == null && r.destinationContainerId == null) continue;

        await TransactionsStore.add(
          Transaction(
            id: '${id}_out',
            label: r.label,
            amount: effectiveAmount,
            date: date,
            type: TransactionType.expense,
            category: r.category,
            containerId: r.containerId,
            transferId: id,
            monthKey: effectiveMonthKey,
          ),
        );

        if (legs != null && legs.isNotEmpty) {
          final destSplitGroupId = '${id}_dst';
          for (int j = 0; j < legs.length; j++) {
            final leg = legs[j];
            await TransactionsStore.add(
              Transaction(
                id: '${id}_in_$j',
                label: r.label,
                amount: leg.amount,
                date: date,
                type: TransactionType.income,
                category: leg.category,
                containerId: leg.containerId,
                transferId: id,
                splitGroupId: destSplitGroupId,
                monthKey: effectiveMonthKey,
              ),
            );
            await BudgetAutomationService.applyCreditRepayment(
              containersStore,
              leg.containerId,
              leg.amount,
            );
          }
        } else {
          await TransactionsStore.add(
            Transaction(
              id: '${id}_in',
              label: r.label,
              amount: effectiveAmount,
              date: date,
              type: TransactionType.income,
              category: r.category,
              containerId: r.destinationContainerId,
              transferId: id,
              monthKey: effectiveMonthKey,
            ),
          );
          await BudgetAutomationService.applyCreditRepayment(
            containersStore,
            r.destinationContainerId,
            effectiveAmount,
          );
        }
      } else {
        await TransactionsStore.add(
          Transaction(
            id: id,
            label: r.label,
            amount: effectiveAmount,
            date: date,
            type: r.type,
            category: r.category,
            containerId: r.containerId,
            monthKey: effectiveMonthKey,
          ),
        );
      }

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
