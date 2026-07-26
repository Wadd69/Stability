class InterestAdjustment {
  /// Conteneur concerné (LEP, Livret A, etc.)
  final String containerId;

  /// Date de la quinzaine (01 ou 16)
  final DateTime quinzaineDate;

  /// Intérêt calculé automatiquement par l’app
  final double computedInterest;

  /// Intérêt validé / corrigé par l’utilisateur
  final double correctedInterest;

  /// Date de validation manuelle
  final DateTime validatedAt;

  /// true = déjà injecté dans TransactionsStore
  /// false = encore seulement calculé
  final bool applied;

  InterestAdjustment({
    required this.containerId,
    required this.quinzaineDate,
    required this.computedInterest,
    required this.correctedInterest,
    DateTime? validatedAt,
    this.applied = false,
  }) : validatedAt = validatedAt ?? DateTime.now();

  // ─────────────────────────────────────────────
  // COPY
  // ─────────────────────────────────────────────

  InterestAdjustment copyWith({
    double? computedInterest,
    double? correctedInterest,
    DateTime? validatedAt,
    bool? applied,
  }) {
    return InterestAdjustment(
      containerId: containerId,
      quinzaineDate: quinzaineDate,
      computedInterest:
          computedInterest ?? this.computedInterest,
      correctedInterest:
          correctedInterest ?? this.correctedInterest,
      validatedAt: validatedAt ?? this.validatedAt,
      applied: applied ?? this.applied,
    );
  }

  // ─────────────────────────────────────────────
  // HIVE SERIALIZATION
  // ─────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'containerId': containerId,
      'quinzaineDate': quinzaineDate.toIso8601String(),
      'computedInterest': computedInterest,
      'correctedInterest': correctedInterest,
      'validatedAt': validatedAt.toIso8601String(),
      'applied': applied,
    };
  }

  factory InterestAdjustment.fromMap(Map<String, dynamic> map) {
    return InterestAdjustment(
      containerId: map['containerId'] as String,
      quinzaineDate:
          DateTime.parse(map['quinzaineDate'] as String),
      computedInterest:
          (map['computedInterest'] as num).toDouble(),
      correctedInterest:
          (map['correctedInterest'] as num).toDouble(),
      validatedAt:
          DateTime.parse(map['validatedAt'] as String),
      applied: map['applied'] as bool? ?? false,
    );
  }
}
