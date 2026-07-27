import 'transaction_type.dart';

enum RecurrenceFrequency { monthly, yearly }

extension RecurrenceFrequencyLabel on RecurrenceFrequency {
  String get label {
    switch (this) {
      case RecurrenceFrequency.monthly:
        return 'Tous les mois';
      case RecurrenceFrequency.yearly:
        return 'Tous les ans';
    }
  }
}

/// Modèle (gabarit) d'une transaction qui se répète automatiquement.
/// La transaction réelle n'est créée qu'au moment où elle devient due
/// (voir RecurringTransactionsStore.generateDueForMonth) — ce modèle
/// ne représente jamais un mouvement d'argent en lui-même.
class RecurringTransaction {
  final String id;
  final String label;
  final double amount;
  final TransactionType type; // income ou expense uniquement
  final String? category;
  final String? containerId;
  final RecurrenceFrequency frequency;
  final int dayOfMonth;
  final String startMonthKey; // "YYYY-MM"
  final String? endMonthKey;
  final String? lastGeneratedMonthKey;
  final bool active;

  RecurringTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
    this.category,
    this.containerId,
    required this.frequency,
    required this.dayOfMonth,
    required this.startMonthKey,
    this.endMonthKey,
    this.lastGeneratedMonthKey,
    this.active = true,
  });

  RecurringTransaction copyWith({
    String? label,
    double? amount,
    TransactionType? type,
    String? category,
    String? containerId,
    RecurrenceFrequency? frequency,
    int? dayOfMonth,
    String? startMonthKey,
    String? endMonthKey,
    String? lastGeneratedMonthKey,
    bool? active,
  }) {
    return RecurringTransaction(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      containerId: containerId ?? this.containerId,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startMonthKey: startMonthKey ?? this.startMonthKey,
      endMonthKey: endMonthKey ?? this.endMonthKey,
      lastGeneratedMonthKey:
          lastGeneratedMonthKey ?? this.lastGeneratedMonthKey,
      active: active ?? this.active,
    );
  }

  /// --- Sérialisation Supabase (colonnes en snake_case) ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      'type': type.name,
      'category': category,
      'container_id': containerId,
      'frequency': frequency.name,
      'day_of_month': dayOfMonth,
      'start_month_key': startMonthKey,
      'end_month_key': endMonthKey,
      'last_generated_month_key': lastGeneratedMonthKey,
      'active': active,
    };
  }

  factory RecurringTransaction.fromMap(Map<dynamic, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      category: map['category'] as String?,
      containerId: map['container_id'] as String?,
      frequency: RecurrenceFrequency.values
          .firstWhere((e) => e.name == map['frequency']),
      dayOfMonth: map['day_of_month'] as int,
      startMonthKey: map['start_month_key'] as String,
      endMonthKey: map['end_month_key'] as String?,
      lastGeneratedMonthKey: map['last_generated_month_key'] as String?,
      active: map['active'] as bool? ?? true,
    );
  }
}
