import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'budget_bucket.dart';

class Category {
  final String id;
  final String name;
  final int colorValue; // Color.value

  /// Classement 50/30/20 (uniquement utilisé dans ce mode de gestion).
  final BudgetBucket? bucket;

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    this.bucket,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'bucket': bucket?.index,
    };
  }

  factory Category.fromMap(Map<dynamic, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['colorValue'] as int?) ??
          _defaultColorForLegacy(map['id'] as String),
      bucket: map['bucket'] != null
          ? BudgetBucket.values[map['bucket'] as int]
          : null,
    );
  }

  // 🔹 Couleur fallback pour anciennes catégories (migration douce)
  static int _defaultColorForLegacy(String seed) {
    final colors = _defaultPalette;
    final index = seed.hashCode.abs() % colors.length;
    return colors[index].toARGB32();
  }

  // Palette interne (stable)
  static final List<Color> _defaultPalette = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
  ];
}

class CategoriesStore {
  static const String _boxName = 'categories';

  static late Box _box;
  static final List<Category> _categories = [];

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _categories
      ..clear()
      ..addAll(
        stored.cast<Map>().map((e) {
          return Category.fromMap(
            Map<String, dynamic>.from(e),
          );
        }),
      );

    // 🔹 Sauvegarde post-migration (si anciennes catégories)
    _save();
  }

  static List<Category> get all =>
      List.unmodifiable(_categories);

  static void _save() {
    _box.put(
      'list',
      _categories.map((c) => c.toMap()).toList(),
    );
  }

  // ✅ Compatible : accepte colorValue: OU color:
  static void add({
    required String name,
    int? colorValue,
    int? color,
    BudgetBucket? bucket,
  }) {
    final resolved = colorValue ?? color ?? Colors.blue.toARGB32();

    final category = Category(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: resolved,
      bucket: bucket,
    );
    _categories.add(category);
    _save();
  }

  // ✅ Compatible : accepte name: OU newName: + colorValue: OU color:
  static void update(
    String id, {
    String? name,
    String? newName,
    int? colorValue,
    int? color,
    BudgetBucket? bucket,
    bool clearBucket = false,
  }) {
    final index =
        _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final old = _categories[index];

    final resolvedName = (name ?? newName ?? old.name).trim();
    final resolvedColor = colorValue ?? color ?? old.colorValue;

    _categories[index] = Category(
      id: old.id,
      name: resolvedName.isEmpty ? old.name : resolvedName,
      colorValue: resolvedColor,
      bucket: clearBucket ? null : (bucket ?? old.bucket),
    );
    _save();
  }

  static void remove(String id) {
    _categories.removeWhere((c) => c.id == id);
    _save();
  }

  // ✅ (tu en as besoin pour tes resets)
  static void clear() {
    _categories.clear();
    _save();
  }

  static Category? getById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
