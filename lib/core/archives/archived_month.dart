import '../finance/transaction.dart';

class ArchivedMonth {
  final String id;
  final int year;
  final int month; // 1–12
  final String label; // ex: "Févr. 2026"

  /// Copie figée des transactions du mois
  final List<Transaction> transactions;

  final double totalIncome;
  final double totalExpense;
  final double balance;

  ArchivedMonth({
    required this.id,
    required this.year,
    required this.month,
    required this.label,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'label': label,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': balance,
    };
  }

  factory ArchivedMonth.fromMap(Map<dynamic, dynamic> map) {
    return ArchivedMonth(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      label: map['label'] as String,
      transactions: (map['transactions'] as List)
          .cast<Map>()
          .map((e) => Transaction.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      totalIncome: (map['totalIncome'] as num).toDouble(),
      totalExpense: (map['totalExpense'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
    );
  }
}
