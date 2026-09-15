import '../../equity/split_rule.dart';
import 'transaction_type.dart';

enum RecurrenceFrequency { monthly, quarterly, semiannual, yearly }

extension RecurrenceFrequencyLabel on RecurrenceFrequency {
  String get label {
    switch (this) {
      case RecurrenceFrequency.monthly:
        return 'Tous les mois';
      case RecurrenceFrequency.quarterly:
        return 'Tous les trimestres';
      case RecurrenceFrequency.semiannual:
        return 'Tous les semestres';
      case RecurrenceFrequency.yearly:
        return 'Tous les ans';
    }
  }

  /// Nombre de mois entre deux occurrences.
  int get intervalMonths {
    switch (this) {
      case RecurrenceFrequency.monthly:
        return 1;
      case RecurrenceFrequency.quarterly:
        return 3;
      case RecurrenceFrequency.semiannual:
        return 6;
      case RecurrenceFrequency.yearly:
        return 12;
    }
  }
}

/// Une destination parmi plusieurs pour un virement récurrent scindé —
/// voir [RecurringTransaction.destinationLegs]. Chaque ligne a son propre
/// support, montant et catégorie (comme les lignes de destination d'un
/// virement ponctuel scindé, voir `_TransferLegLine`).
class RecurringTransferLeg {
  final String containerId;
  final String? category;
  final double amount;

  const RecurringTransferLeg({
    required this.containerId,
    this.category,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
        'container_id': containerId,
        'category': category,
        'amount': amount,
      };

  factory RecurringTransferLeg.fromMap(Map<dynamic, dynamic> map) =>
      RecurringTransferLeg(
        containerId: map['container_id'] as String,
        category: map['category'] as String?,
        amount: (map['amount'] as num).toDouble(),
      );
}

/// Modèle (gabarit) d'une transaction qui se répète automatiquement.
/// La transaction réelle n'est créée qu'au moment où elle devient due
/// (voir RecurringTransactionsStore.generateDueForMonth) — ce modèle
/// ne représente jamais un mouvement d'argent en lui-même.
class RecurringTransaction {
  final String id;
  final String label;
  final double amount;
  final TransactionType type; // income, expense ou transfer
  final String? category;
  final String? containerId;

  /// Support de destination — utilisé uniquement si [type] est
  /// [TransactionType.transfer] ([containerId] sert alors de source).
  final String? destinationContainerId;

  /// Scinde la destination du virement sur plusieurs supports/catégories,
  /// chacun avec son propre montant (dont la somme doit égaler [amount]).
  /// `null`/vide = destination unique via [destinationContainerId].
  final List<RecurringTransferLeg>? destinationLegs;
  final RecurrenceFrequency frequency;
  final int dayOfMonth;
  final String startMonthKey; // "YYYY-MM"
  final String? endMonthKey;
  final String? lastGeneratedMonthKey;
  final bool active;

  /// Surcharge de répartition entre membres pour cette récurrence
  /// spécifique — `null` = suivre la règle de la catégorie (voir
  /// [Category.splitRule]).
  final SplitRule? splitRule;

  /// Si vrai, l'écran "Prévision" range cette occurrence dans le mois
  /// suivant plutôt que dans le mois où elle tombe réellement — utile pour
  /// un salaire versé en fin de mois qui finance en pratique le mois
  /// d'après. N'affecte que l'affichage de la prévision, jamais la vraie
  /// date de génération de la transaction.
  final bool countsForNextMonth;

  RecurringTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.type,
    this.category,
    this.containerId,
    this.destinationContainerId,
    this.destinationLegs,
    required this.frequency,
    required this.dayOfMonth,
    required this.startMonthKey,
    this.endMonthKey,
    this.lastGeneratedMonthKey,
    this.active = true,
    this.splitRule,
    this.countsForNextMonth = false,
  });

  RecurringTransaction copyWith({
    String? label,
    double? amount,
    TransactionType? type,
    String? category,
    String? containerId,
    String? destinationContainerId,
    List<RecurringTransferLeg>? destinationLegs,
    bool clearDestinationLegs = false,
    RecurrenceFrequency? frequency,
    int? dayOfMonth,
    String? startMonthKey,
    String? endMonthKey,
    String? lastGeneratedMonthKey,
    bool? active,
    SplitRule? splitRule,
    bool clearSplitRule = false,
    bool? countsForNextMonth,
  }) {
    return RecurringTransaction(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      containerId: containerId ?? this.containerId,
      destinationContainerId:
          destinationContainerId ?? this.destinationContainerId,
      destinationLegs: clearDestinationLegs
          ? null
          : (destinationLegs ?? this.destinationLegs),
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startMonthKey: startMonthKey ?? this.startMonthKey,
      endMonthKey: endMonthKey ?? this.endMonthKey,
      lastGeneratedMonthKey:
          lastGeneratedMonthKey ?? this.lastGeneratedMonthKey,
      active: active ?? this.active,
      splitRule: clearSplitRule ? null : (splitRule ?? this.splitRule),
      countsForNextMonth: countsForNextMonth ?? this.countsForNextMonth,
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
      'destination_container_id': destinationContainerId,
      'destination_legs': destinationLegs?.map((l) => l.toMap()).toList(),
      'frequency': frequency.name,
      'day_of_month': dayOfMonth,
      'start_month_key': startMonthKey,
      'end_month_key': endMonthKey,
      'last_generated_month_key': lastGeneratedMonthKey,
      'active': active,
      'split_rule': splitRule?.toMap(),
      'counts_for_next_month': countsForNextMonth,
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
      destinationContainerId: map['destination_container_id'] as String?,
      destinationLegs: (map['destination_legs'] as List<dynamic>?)
          ?.map(
              (e) => RecurringTransferLeg.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      frequency: RecurrenceFrequency.values
          .firstWhere((e) => e.name == map['frequency']),
      dayOfMonth: map['day_of_month'] as int,
      startMonthKey: map['start_month_key'] as String,
      endMonthKey: map['end_month_key'] as String?,
      lastGeneratedMonthKey: map['last_generated_month_key'] as String?,
      active: map['active'] as bool? ?? true,
      splitRule: map['split_rule'] != null
          ? SplitRule.fromMap(Map<String, dynamic>.from(map['split_rule']))
          : null,
      countsForNextMonth: map['counts_for_next_month'] as bool? ?? false,
    );
  }
}
