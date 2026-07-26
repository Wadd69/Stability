import 'package:hive/hive.dart';

import 'recurring_transaction.dart';
import 'transaction.dart';
import 'transactions_store.dart';

class RecurringTransactionsStore {
  static const String _boxName = 'recurring_transactions';

  static late Box _box;
  static final List<RecurringTransaction> _items = [];

  static Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _items
      ..clear()
      ..addAll(
        stored.cast<Map>().map(
              (e) => RecurringTransaction.fromMap(
                Map<String, dynamic>.from(e),
              ),
            ),
      );
  }

  static List<RecurringTransaction> get all => List.unmodifiable(_items);

  static void _save() {
    _box.put('list', _items.map((r) => r.toMap()).toList());
  }

  static void add(RecurringTransaction recurring) {
    _items.add(recurring);
    _save();
  }

  static void update(RecurringTransaction recurring) {
    final index = _items.indexWhere((r) => r.id == recurring.id);
    if (index == -1) return;
    _items[index] = recurring;
    _save();
  }

  static void remove(String id) {
    _items.removeWhere((r) => r.id == id);
    _save();
  }

  static void setActive(String id, bool active) {
    final index = _items.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(active: active);
    _save();
  }

  static void clear() {
    _items.clear();
    _save();
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
  static int generateDueForMonth(String monthKey) {
    int count = 0;

    for (int i = 0; i < _items.length; i++) {
      final r = _items[i];
      if (!_isDue(r, monthKey)) continue;

      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final day = r.dayOfMonth.clamp(1, lastDayOfMonth);

      TransactionsStore.add(
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

      _items[i] = r.copyWith(lastGeneratedMonthKey: monthKey);
      count++;
    }

    if (count > 0) _save();
    return count;
  }
}
