enum BudgetRuleScope {
  global,
  category,
  account,
}

class BudgetRule {
  final String id;
  final String name;
  final bool enabled;
  final BudgetRuleScope scope;

  /// Configuration libre, interprétée par le moteur
  /// Exemple futur :
  /// { "limit": 500, "categoryId": "xxx" }
  final Map<String, dynamic> config;

  BudgetRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.scope,
    required this.config,
  });

  BudgetRule copyWith({
    String? name,
    bool? enabled,
    BudgetRuleScope? scope,
    Map<String, dynamic>? config,
  }) {
    return BudgetRule(
      id: id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      scope: scope ?? this.scope,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'scope': scope.name,
      'config': config,
    };
  }

  factory BudgetRule.fromMap(Map<dynamic, dynamic> map) {
    return BudgetRule(
      id: map['id'] as String,
      name: map['name'] as String,
      enabled: map['enabled'] as bool,
      scope: BudgetRuleScope.values.firstWhere(
        (e) => e.name == map['scope'],
      ),
      config: Map<String, dynamic>.from(
        map['config'] as Map,
      ),
    );
  }
}
