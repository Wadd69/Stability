import 'package:stability/core/finance/transaction_type.dart';

class Transaction {
  final String id;
  final String label;
  final double amount;
  final DateTime date;
  final TransactionType type;

  final String? category;
  final String? containerId;
  final String? transferId;

  /// Regroupe les lignes issues d'un même split (une dépense répartie
  /// sur plusieurs catégories). null => transaction normale, non divisée.
  final String? splitGroupId;

  final bool isInterest;
  final bool isCleared;
  final bool isArchived;
  final bool isCarryOver;

  final String monthKey;

  /// ✅ NOUVEAU : mois d’origine (si carryOver)
  /// - null => transaction “normale” du mois
  /// - non-null => transaction créée un mois précédent, visible ce mois-ci
  final String? originMonthKey;

  Transaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.type,
    this.category,
    this.containerId,
    this.transferId,
    this.splitGroupId,
    this.isInterest = false,
    this.isCleared = false,
    this.isArchived = false,
    this.isCarryOver = false,
    required this.monthKey,
    this.originMonthKey, // ✅
  });

  Transaction copyWith({
    String? label,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? containerId,
    String? transferId,
    String? splitGroupId,
    bool? isInterest,
    bool? isCleared,
    bool? isArchived,
    bool? isCarryOver,
    String? monthKey,
    String? originMonthKey, // ✅
  }) {
    return Transaction(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      containerId: containerId ?? this.containerId,
      transferId: transferId ?? this.transferId,
      splitGroupId: splitGroupId ?? this.splitGroupId,
      isInterest: isInterest ?? this.isInterest,
      isCleared: isCleared ?? this.isCleared,
      isArchived: isArchived ?? this.isArchived,
      isCarryOver: isCarryOver ?? this.isCarryOver,
      monthKey: monthKey ?? this.monthKey,
      originMonthKey: originMonthKey ?? this.originMonthKey, // ✅
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category,
      'containerId': containerId,
      'transferId': transferId,
      'splitGroupId': splitGroupId,
      'isInterest': isInterest,
      'isCleared': isCleared,
      'isArchived': isArchived,
      'isCarryOver': isCarryOver,
      'monthKey': monthKey,
      'originMonthKey': originMonthKey, // ✅
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      category: map['category'] as String?,
      containerId: map['containerId'] as String?,
      transferId: map['transferId'] as String?,
      splitGroupId: map['splitGroupId'] as String?,
      isInterest: (map['isInterest'] as bool?) ?? false,
      isCleared: (map['isCleared'] as bool?) ?? false,
      isArchived: (map['isArchived'] as bool?) ?? false,
      isCarryOver: (map['isCarryOver'] as bool?) ?? false,
      monthKey: map['monthKey'] as String,
      originMonthKey: map['originMonthKey'] as String?, // ✅
    );
  }
}
