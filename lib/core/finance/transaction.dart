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

  /// Membre du compte partagé qui a réellement payé cette dépense —
  /// sert au calcul du solde entre membres (voir
  /// [EquitySettlementService]). `null` = non renseigné (compte solo,
  /// ou transaction créée avant l'ajout de cette fonctionnalité).
  final String? paidByUserId;

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
    this.paidByUserId,
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
    String? paidByUserId,
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
      paidByUserId: paidByUserId ?? this.paidByUserId,
    );
  }

  /// --- Sérialisation Supabase (colonnes en snake_case) ---
  /// Ne contient pas `account_id` : ajouté par le store à l'insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category,
      'container_id': containerId,
      'transfer_id': transferId,
      'split_group_id': splitGroupId,
      'is_interest': isInterest,
      'is_cleared': isCleared,
      'is_archived': isArchived,
      'is_carry_over': isCarryOver,
      'month_key': monthKey,
      'origin_month_key': originMonthKey,
      'paid_by_user_id': paidByUserId,
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
      containerId: map['container_id'] as String?,
      transferId: map['transfer_id'] as String?,
      splitGroupId: map['split_group_id'] as String?,
      isInterest: (map['is_interest'] as bool?) ?? false,
      isCleared: (map['is_cleared'] as bool?) ?? false,
      isArchived: (map['is_archived'] as bool?) ?? false,
      isCarryOver: (map['is_carry_over'] as bool?) ?? false,
      monthKey: map['month_key'] as String,
      originMonthKey: map['origin_month_key'] as String?,
      paidByUserId: map['paid_by_user_id'] as String?,
    );
  }
}
