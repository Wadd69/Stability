import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';

/// Stocke UNIQUEMENT les soldes d’ouverture par mois et par conteneur.
/// 👉 Aucune transaction ici.
/// 👉 Aucune logique de pointage.
/// 👉 Source de vérité du solde quand on change de mois.
///
/// Stockée sur Supabase (table `monthly_balances`), scopée par compte.
/// Lecture toujours synchrone (cache en mémoire) ; seules les écritures et
/// [init] font un aller-retour réseau.
class MonthlyBalancesStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final Map<String, double> _balances = {};

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    _balances.clear();

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    final rows = await _client
        .from('monthly_balances')
        .select()
        .eq('account_id', accountId);

    for (final r in (rows as List)) {
      final row = r as Map<String, dynamic>;
      _balances[
              _key(row['month_key'] as String, row['container_id'] as String)] =
          (row['opening_balance'] as num).toDouble();
    }
  }

  // ─────────────────────────────────────────────
  // INTERNAL KEY
  // ─────────────────────────────────────────────
  static String _key(String monthKey, String containerId) =>
      '$monthKey::$containerId';

  // ─────────────────────────────────────────────
  // API — SOLDE D’OUVERTURE
  // ─────────────────────────────────────────────
  static double getOpeningBalance(String monthKey, String containerId) {
    return _balances[_key(monthKey, containerId)] ?? 0.0;
  }

  /// Distingue "jamais défini" de "défini à 0€" — contrairement à
  /// [getOpeningBalance], qui renvoie 0.0 par défaut dans les deux cas.
  /// Sert de garde-fou d'idempotence (voir TransactionsStore.closeMonth).
  static bool hasOpeningBalance(String monthKey, String containerId) {
    return _balances.containsKey(_key(monthKey, containerId));
  }

  static Future<void> setOpeningBalance(
    String monthKey,
    String containerId,
    double value,
  ) async {
    _balances[_key(monthKey, containerId)] = value;

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('monthly_balances').upsert({
      'account_id': accountId,
      'month_key': monthKey,
      'container_id': containerId,
      'opening_balance': value,
    });
  }

  // ─────────────────────────────────────────────
  // LISTE DES CONTENEURS AYANT UN SOLDE POUR UN MOIS
  // (important pour propager aussi les comptes sans transaction)
  // ─────────────────────────────────────────────
  static List<String> containerIdsForMonth(String monthKey) {
    final prefix = '$monthKey::';
    return _balances.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();
  }

  // ─────────────────────────────────────────────
  // PROPAGATION (ancienne)
  // ─────────────────────────────────────────────
  static Future<void> propagateToNextMonth({
    required String currentMonthKey,
    required String nextMonthKey,
  }) async {
    final prefix = '$currentMonthKey::';
    final matches =
        _balances.entries.where((e) => e.key.startsWith(prefix)).toList();

    for (final e in matches) {
      final containerId = e.key.substring(prefix.length);
      await setOpeningBalance(nextMonthKey, containerId, e.value);
    }
  }

  // ─────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client
          .from('monthly_balances')
          .delete()
          .eq('account_id', accountId);
    }
    _balances.clear();
  }
}
