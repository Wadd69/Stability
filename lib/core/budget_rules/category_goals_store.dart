import 'package:hive/hive.dart';

/// Objectif d'épargne optionnel pour une catégorie (ex: "Vacances : 600€").
/// La progression n'est jamais stockée ici : elle correspond au solde
/// courant de l'enveloppe (CategoryAllocationsStore.remaining), qui
/// s'accumule mois après mois tant qu'il n'est pas dépensé.
class CategoryGoalsStore {
  static const String _boxName = 'category_goals';
  static late Box _box;

  static Future<void> init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  static double? getGoal(String categoryId) {
    final value = _box.get(categoryId);
    return (value as num?)?.toDouble();
  }

  static void setGoal(String categoryId, double? amount) {
    if (amount == null || amount <= 0) {
      _box.delete(categoryId);
    } else {
      _box.put(categoryId, amount);
    }
  }
}
