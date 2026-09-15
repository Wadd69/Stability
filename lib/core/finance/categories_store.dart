import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import '../../equity/split_rule.dart';

class Category {
  final String id;
  final String name;
  final int colorValue; // Color.value

  /// Enveloppe de la méthode "pourcentages personnalisés" (uniquement
  /// utilisé dans ce mode de gestion) — id référençant une entrée de
  /// CloudAccount.effectiveBuckets.
  final String? bucketId;

  /// Règle de répartition entre membres d'un compte partagé pour les
  /// dépenses de cette catégorie. `null` = répartition au prorata des
  /// revenus (voir [SplitRule.proportional]).
  final SplitRule? splitRule;

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    this.bucketId,
    this.splitRule,
  });

  /// --- Sérialisation Supabase (colonnes en snake_case) ---
  /// Ne contient pas `account_id` : ajouté par le store à l'insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'bucket': bucketId,
      'split_rule': splitRule?.toMap(),
    };
  }

  factory Category.fromMap(Map<dynamic, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['color_value'] as int?) ??
          _defaultColorForLegacy(map['id'] as String),
      bucketId: map['bucket'] as String?,
      splitRule: map['split_rule'] != null
          ? SplitRule.fromMap(Map<String, dynamic>.from(map['split_rule']))
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

/// Catégories du compte cloud actif — stockées sur Supabase (table
/// `categories`), scopées par `account_id`. Lecture toujours synchrone
/// (cache en mémoire) ; seules les écritures et [init] font un
/// aller-retour réseau.
class CategoriesStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<Category> _categories = [];

  /// Recharge les catégories du compte actif depuis Supabase.
  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _categories.clear();
      return;
    }

    final rows =
        await _client.from('categories').select().eq('account_id', accountId);

    _categories
      ..clear()
      ..addAll(
        (rows as List).map((r) => Category.fromMap(r as Map<String, dynamic>)),
      );
  }

  static List<Category> get all => List.unmodifiable(_categories);

  // ✅ Compatible : accepte colorValue: OU color:
  static Future<void> add({
    required String name,
    int? colorValue,
    int? color,
    String? bucketId,
    String? id,
    SplitRule? splitRule,
  }) async {
    final resolved = colorValue ?? color ?? Colors.blue.toARGB32();

    final category = Category(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: resolved,
      bucketId: bucketId,
      splitRule: splitRule,
    );

    await _client.from('categories').insert({
      ...category.toMap(),
      'account_id': CurrentAccount.active.id,
    });

    _categories.add(category);
  }

  // ✅ Compatible : accepte name: OU newName: + colorValue: OU color:
  static Future<void> update(
    String id, {
    String? name,
    String? newName,
    int? colorValue,
    int? color,
    String? bucketId,
    bool clearBucket = false,
    SplitRule? splitRule,
    bool clearSplitRule = false,
  }) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final old = _categories[index];

    final resolvedName = (name ?? newName ?? old.name).trim();
    final resolvedColor = colorValue ?? color ?? old.colorValue;

    final updated = Category(
      id: old.id,
      name: resolvedName.isEmpty ? old.name : resolvedName,
      colorValue: resolvedColor,
      bucketId: clearBucket ? null : (bucketId ?? old.bucketId),
      splitRule: clearSplitRule ? null : (splitRule ?? old.splitRule),
    );

    await _client.from('categories').update(updated.toMap()).eq('id', id);

    _categories[index] = updated;
  }

  static Future<void> remove(String id) async {
    await _client.from('categories').delete().eq('id', id);
    _categories.removeWhere((c) => c.id == id);
  }

  // ✅ (tu en as besoin pour tes resets)
  static Future<void> clear() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client.from('categories').delete().eq('account_id', accountId);
    }
    _categories.clear();
  }

  static Category? getById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
