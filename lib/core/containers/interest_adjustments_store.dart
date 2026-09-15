import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import 'interest_adjustment.dart';

/// Ajustements d'intérêts par quinzaine et par support — stockés sur
/// Supabase (table `interest_adjustments`), scopés par compte. Clé
/// naturelle : (containerId, quinzaineDate).
class InterestAdjustmentsStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<InterestAdjustment> _items = [];

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _items.clear();
      return;
    }

    final rows = await _client
        .from('interest_adjustments')
        .select()
        .eq('account_id', accountId);

    _items
      ..clear()
      ..addAll(
        (rows as List)
            .map((r) => InterestAdjustment.fromMap(r as Map<String, dynamic>)),
      );
  }

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────
  static List<InterestAdjustment> get all => List.unmodifiable(_items);

  /// Récupère l’ajustement pour une quinzaine donnée
  static InterestAdjustment? getFor(
    String containerId,
    DateTime quinzaineDate,
  ) {
    try {
      return _items.firstWhere(
        (e) => e.containerId == containerId && e.quinzaineDate == quinzaineDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ajustements non encore injectés dans les transactions
  static List<InterestAdjustment> pendingForContainer(
    String containerId,
  ) {
    return _items
        .where(
          (e) => e.containerId == containerId && e.applied == false,
        )
        .toList();
  }

  // ─────────────────────────────────────────────
  // WRITE
  // ─────────────────────────────────────────────

  static Future<void> addOrUpdate(InterestAdjustment adj) async {
    final index = _items.indexWhere(
      (e) =>
          e.containerId == adj.containerId &&
          e.quinzaineDate == adj.quinzaineDate,
    );

    if (index == -1) {
      _items.add(adj);
    } else {
      _items[index] = adj;
    }

    await _client.from('interest_adjustments').upsert({
      ...adj.toMap(),
      'account_id': CurrentAccount.active.id,
    });
  }

  static Future<void> markAsApplied(InterestAdjustment adj) async {
    final index = _items.indexWhere(
      (e) =>
          e.containerId == adj.containerId &&
          e.quinzaineDate == adj.quinzaineDate,
    );

    if (index == -1) return;

    final updated = adj.copyWith(applied: true);
    _items[index] = updated;

    await _client.from('interest_adjustments').upsert({
      ...updated.toMap(),
      'account_id': CurrentAccount.active.id,
    });
  }
}
