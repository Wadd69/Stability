/// Résumé d'un mois archivé. Ne contient plus les transactions elles-mêmes
/// (ancienne duplication corrigée) — celles-ci restent des lignes normales
/// dans `TransactionsStore` (`isArchived = true`, `monthKey` correspondant),
/// consultables via `TransactionsStore.archivedForMonth(id)`.
class ArchivedMonth {
  final String id; // = monthKey ("YYYY-MM")
  final int year;
  final int month; // 1–12
  final String label; // ex: "Févr. 2026"

  final double totalIncome;
  final double totalExpense;
  final double balance;

  ArchivedMonth({
    required this.id,
    required this.year,
    required this.month,
    required this.label,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  /// --- Sérialisation Supabase (colonnes en snake_case) ---
  Map<String, dynamic> toMap() {
    return {
      'month_key': id,
      'year': year,
      'month': month,
      'label': label,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'balance': balance,
    };
  }

  factory ArchivedMonth.fromMap(Map<dynamic, dynamic> map) {
    return ArchivedMonth(
      id: map['month_key'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      label: map['label'] as String,
      totalIncome: (map['total_income'] as num).toDouble(),
      totalExpense: (map['total_expense'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
    );
  }
}
