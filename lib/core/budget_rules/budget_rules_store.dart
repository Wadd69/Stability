import 'package:hive/hive.dart';

import 'budget_rule.dart';

class BudgetRulesStore {
  static const String _boxName = 'budget_rules';

  static late Box _box;
  static final List<BudgetRule> _rules = [];

  // 🔹 INIT
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _rules
      ..clear()
      ..addAll(
        stored
            .cast<Map>()
            .map((e) => BudgetRule.fromMap(
                  Map<String, dynamic>.from(e),
                )),
      );
  }

  // 🔹 Lecture
  static List<BudgetRule> get all =>
      List.unmodifiable(_rules);

  static List<BudgetRule> get enabled =>
      _rules.where((r) => r.enabled).toList();

  // 🔹 Persistance
  static void _save() {
    _box.put(
      'list',
      _rules.map((r) => r.toMap()).toList(),
    );
  }

  // ➕ Ajouter une règle
  static void add(BudgetRule rule) {
    _rules.add(rule);
    _save();
  }

  // ✏️ Mettre à jour
  static void update(BudgetRule rule) {
    final index =
        _rules.indexWhere((r) => r.id == rule.id);
    if (index == -1) return;

    _rules[index] = rule;
    _save();
  }

  // ❌ Supprimer
  static void remove(String id) {
    _rules.removeWhere((r) => r.id == id);
    _save();
  }

  // 🔥 RESET DEV
  static void clear() {
    _rules.clear();
    _save();
  }
}
