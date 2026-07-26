enum BudgetRuleStatus {
  ok,
  warning,
  exceeded,
}

class BudgetRuleResult {
  final String ruleId;
  final BudgetRuleStatus status;

  /// Message prêt à afficher
  final String message;

  /// Valeur observée (ex: dépense réelle)
  final double? currentValue;

  /// Valeur limite (ex: plafond)
  final double? limitValue;

  BudgetRuleResult({
    required this.ruleId,
    required this.status,
    required this.message,
    this.currentValue,
    this.limitValue,
  });
}
