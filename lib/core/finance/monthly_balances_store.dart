import 'package:hive/hive.dart';

/// Stocke UNIQUEMENT les soldes d’ouverture par mois et par conteneur.
/// 👉 Aucune transaction ici.
/// 👉 Aucune logique de pointage.
/// 👉 Source de vérité du solde quand on change de mois.
class MonthlyBalancesStore {
  static const String _boxName = 'monthly_balances';
  static late Box _box;

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
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
    if (!_box.isOpen) return 0.0;
    return (_box.get(_key(monthKey, containerId)) ?? 0.0).toDouble();
  }

  static void setOpeningBalance(
    String monthKey,
    String containerId,
    double value,
  ) {
    if (!_box.isOpen) return;
    _box.put(_key(monthKey, containerId), value);
  }

  // ─────────────────────────────────────────────
  // LISTE DES CONTENEURS AYANT UN SOLDE POUR UN MOIS
  // (important pour propager aussi les comptes sans transaction)
  // ─────────────────────────────────────────────
  static List<String> containerIdsForMonth(String monthKey) {
    if (!_box.isOpen) return const [];

    final keys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith('$monthKey::'))
        .toList();

    final out = <String>[];
    for (final k in keys) {
      final parts = k.split('::');
      if (parts.length == 2) out.add(parts[1]);
    }
    return out;
  }

  // ─────────────────────────────────────────────
  // PROPAGATION (ancienne)
  // ─────────────────────────────────────────────
  static void propagateToNextMonth({
    required String currentMonthKey,
    required String nextMonthKey,
  }) {
    if (!_box.isOpen) return;

    final keys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith('$currentMonthKey::'))
        .toList();

    for (final key in keys) {
      final parts = key.split('::');
      if (parts.length != 2) continue;

      final containerId = parts[1];
      final value = (_box.get(key) ?? 0.0).toDouble();

      _box.put('$nextMonthKey::$containerId', value);
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
