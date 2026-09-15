import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';

/// Montant corrigé pour une occurrence précise d'une transaction
/// récurrente (ex: salaire dont le montant varie chaque mois) — surcharge
/// ponctuelle, ne change jamais le montant par défaut du gabarit. Consommé
/// une fois par `RecurringTransactionsStore.generateDueForMonth` lors de la
/// génération réelle, et affiché par [ForecastService] en attendant.
class RecurringOverridesStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final Map<String, double> _overrides = {};

  static String _key(String recurringId, String monthKey) =>
      '${recurringId}_$monthKey';

  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _overrides.clear();
      return;
    }

    final rows = await _client
        .from('recurring_overrides')
        .select()
        .eq('account_id', accountId);

    _overrides
      ..clear()
      ..addEntries((rows as List).map(
        (r) => MapEntry(
          _key(r['recurring_id'] as String, r['month_key'] as String),
          (r['amount'] as num).toDouble(),
        ),
      ));
  }

  static double? getOverride(String recurringId, String monthKey) =>
      _overrides[_key(recurringId, monthKey)];

  static Future<void> setOverride(
    String recurringId,
    String monthKey,
    double amount,
  ) async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('recurring_overrides').upsert({
      'account_id': accountId,
      'recurring_id': recurringId,
      'month_key': monthKey,
      'amount': amount,
    });
    _overrides[_key(recurringId, monthKey)] = amount;
  }

  /// Supprime la surcharge — utilisé après consommation lors de la
  /// génération réelle, pour ne garder en base que les surcharges encore
  /// en attente.
  static Future<void> clearOverride(String recurringId, String monthKey) async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client
        .from('recurring_overrides')
        .delete()
        .eq('account_id', accountId)
        .eq('recurring_id', recurringId)
        .eq('month_key', monthKey);
    _overrides.remove(_key(recurringId, monthKey));
  }
}
