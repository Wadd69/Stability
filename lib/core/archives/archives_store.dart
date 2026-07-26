import 'package:hive/hive.dart';

import 'archived_month.dart';
import '../finance/transaction.dart';
import '../finance/transaction_type.dart';

class ArchivesStore {
  static const String _boxName = 'archives';

  static late Box _box;
  static final List<ArchivedMonth> _months = [];

  // 🔹 INIT
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _months
      ..clear()
      ..addAll(
        stored
            .cast<Map>()
            .map((e) => ArchivedMonth.fromMap(
                  Map<String, dynamic>.from(e),
                )),
      );
  }

  // 🔹 Lecture
  static List<ArchivedMonth> get all =>
      List.unmodifiable(_months);

  static List<int> get years =>
      _months.map((m) => m.year).toSet().toList()..sort();

  static List<ArchivedMonth> byYear(int year) {
    return _months
        .where((m) => m.year == year)
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  /// 🔹 MOIS PRÉCÉDENT
  static ArchivedMonth? getPreviousMonth(int year, int month) {
    try {
      return _months
          .where((m) =>
              m.year < year ||
              (m.year == year && m.month < month))
          .reduce((a, b) =>
              (a.year * 12 + a.month) >
                      (b.year * 12 + b.month)
                  ? a
                  : b);
    } catch (_) {
      return null;
    }
  }

  // 🔹 Persistance
  static void _save() {
    _box.put(
      'list',
      _months.map((m) => m.toMap()).toList(),
    );
  }

  // ➕ Ajouter / remplacer un mois archivé
  static void add(ArchivedMonth month) {
    _months.removeWhere((m) => m.id == month.id);
    _months.add(month);
    _save();
  }

  // ✅ NOUVEAU — création explicite d’un mois archivé
  static void archiveMonth({
    required String monthKey,
    required List<Transaction> transactions,
    required double openingBalance,
    required double closingBalance,
    required String label,
  }) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);

    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final archived = ArchivedMonth(
      id: monthKey,
      year: year,
      month: month,
      label: label,
      transactions: List<Transaction>.from(transactions),
      totalIncome: income,
      totalExpense: expense,
      balance: closingBalance,
    );

    add(archived);
  }

  // 🔥 RESET DEV
  static void clear() {
    _months.clear();
    _save();
  }
}
