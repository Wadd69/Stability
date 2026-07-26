import '../archives/archived_month.dart';
import 'package:stability/core/finance/finance.dart';

enum ComparisonPeriodType {
  month,
  year,
}

class ComparisonPeriod {
  final ComparisonPeriodType type;

  /// Identité lisible (ex: "Févr. 2026", "Année 2027")
  final String label;

  /// Année concernée (toujours définie)
  final int year;

  /// Mois concerné (uniquement si type == month)
  final int? month;

  /// Source brute (un ou plusieurs ArchivedMonth)
  final List<ArchivedMonth> sourceMonths;

  /// Transactions normalisées (fusionnées si année)
  final List<Transaction> transactions;

  /// Agrégats prêts à l’emploi
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const ComparisonPeriod._({
    required this.type,
    required this.label,
    required this.year,
    required this.month,
    required this.sourceMonths,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  // ─────────────────────────────────────────────
  // 🔹 FACTORY : MOIS
  // ─────────────────────────────────────────────
  factory ComparisonPeriod.fromMonth(ArchivedMonth month) {
    return ComparisonPeriod._(
      type: ComparisonPeriodType.month,
      label: month.label,
      year: month.year,
      month: month.month,
      sourceMonths: [month],
      transactions: List.unmodifiable(month.transactions),
      totalIncome: month.totalIncome,
      totalExpense: month.totalExpense,
      balance: month.balance,
    );
  }

  // ─────────────────────────────────────────────
  // 🔹 FACTORY : ANNÉE
  // ─────────────────────────────────────────────
  factory ComparisonPeriod.fromYear(
    int year,
    List<ArchivedMonth> months,
  ) {
    final List<Transaction> tx = [];
    double income = 0;
    double expense = 0;

    for (final m in months) {
      tx.addAll(m.transactions);
      income += m.totalIncome;
      expense += m.totalExpense;
    }

    return ComparisonPeriod._(
      type: ComparisonPeriodType.year,
      label: 'Année $year',
      year: year,
      month: null,
      sourceMonths: List.unmodifiable(months),
      transactions: List.unmodifiable(tx),
      totalIncome: income,
      totalExpense: expense,
      balance: income - expense,
    );
  }

  // ─────────────────────────────────────────────
  // 🔹 HELPERS
  // ─────────────────────────────────────────────

  bool get isMonth => type == ComparisonPeriodType.month;
  bool get isYear => type == ComparisonPeriodType.year;

  /// Identifiant stable (utile pour légendes / couleurs)
  String get id =>
      isMonth ? '$year-${month.toString().padLeft(2, '0')}' : '$year';

  @override
  String toString() => label;
}
