/// Mode de répartition d'une dépense entre les membres d'un compte
/// partagé.
enum SplitMode {
  /// Au prorata des revenus déclarés par chaque membre (mode par défaut).
  proportional,

  /// Parts égales entre tous les membres.
  equal,

  /// Pourcentages choisis manuellement par membre (voir [SplitRule.customPercents]).
  custom,

  /// Un seul membre paie l'intégralité (voir [SplitRule.assignedUserId]).
  assigned,
}

extension SplitModeLabel on SplitMode {
  String get label {
    switch (this) {
      case SplitMode.proportional:
        return 'Proportionnel aux revenus';
      case SplitMode.equal:
        return 'Parts égales';
      case SplitMode.custom:
        return 'Pourcentages personnalisés';
      case SplitMode.assigned:
        return 'Un seul membre paie';
    }
  }
}

/// Règle de répartition d'une dépense entre les membres d'un compte
/// partagé — attachée à une catégorie (règle par défaut) ou à une
/// transaction récurrente (surcharge ponctuelle). `null` là où ce type
/// est utilisé signifie "hériter de la règle du niveau au-dessus"
/// (catégorie, ou à défaut [SplitMode.proportional]).
class SplitRule {
  final SplitMode mode;

  /// Pourcentages par membre (0-100, doivent totaliser 100) — utilisé
  /// uniquement si [mode] est [SplitMode.custom].
  final Map<String, double>? customPercents;

  /// Membre qui paie seul — utilisé uniquement si [mode] est
  /// [SplitMode.assigned].
  final String? assignedUserId;

  const SplitRule({
    required this.mode,
    this.customPercents,
    this.assignedUserId,
  });

  static const proportional = SplitRule(mode: SplitMode.proportional);
  static const equal = SplitRule(mode: SplitMode.equal);

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'custom_percents': customPercents,
      'assigned_user_id': assignedUserId,
    };
  }

  factory SplitRule.fromMap(Map<dynamic, dynamic> map) {
    return SplitRule(
      mode: SplitMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => SplitMode.proportional,
      ),
      customPercents: (map['custom_percents'] as Map?)
          ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      assignedUserId: map['assigned_user_id'] as String?,
    );
  }
}
