import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import 'container_model.dart';
import 'container_type.dart';

/// Supports ("comptes") du compte cloud actif — stockés sur Supabase
/// (table `containers`), scopés par `account_id`. La liste en mémoire
/// reste synchrone pour la lecture (`all`/`active`/...) ; seules les
/// opérations d'écriture et [init] font un aller-retour réseau.
class ContainersStore extends ChangeNotifier {
  static SupabaseClient get _client => Supabase.instance.client;

  final List<ContainerModel> _containers = [];

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────

  List<ContainerModel> get all => List.unmodifiable(_containers);

  List<ContainerModel> get active =>
      _containers.where((c) => !c.isArchived).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<ContainerModel> get archived =>
      _containers.where((c) => c.isArchived).toList();

  /// 🔹 Compte courant principal (source de vérité)
  ContainerModel? get primaryCurrentAccount {
    try {
      return _containers.firstWhere(
        (c) =>
            c.type == ContainerType.currentAccount &&
            c.isPrimary &&
            !c.isArchived,
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  /// Recharge les supports du compte actif depuis Supabase. À appeler
  /// après connexion et à chaque changement de compte actif — ne dépend
  /// plus du lancement de l'app puisque les données sont scopées par
  /// compte, connu seulement après authentification.
  Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _containers.clear();
      notifyListeners();
      return;
    }

    final rows =
        await _client.from('containers').select().eq('account_id', accountId);

    _containers
      ..clear()
      ..addAll(
        (rows as List)
            .map((r) => ContainerModel.fromMap(r as Map<String, dynamic>)),
      );

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────

  Future<ContainerModel> createContainer({
    required String name,
    required int colorValue,
    required ContainerType type,
    List<InterestRatePeriod>? interestRates,
    CreditKind? creditKind,
    double? creditOriginalAmount,
    double? creditRemainingBalance,
    double? creditMonthlyPayment,
    double? creditAnnualRate,
  }) async {
    final container = ContainerModel(
      id: UniqueKey().toString(),
      name: name,
      colorValue: colorValue,
      type: type,
      interestRates: interestRates ?? [],
      creditKind: creditKind,
      creditOriginalAmount: creditOriginalAmount,
      creditRemainingBalance: creditRemainingBalance,
      creditMonthlyPayment: creditMonthlyPayment,
      creditAnnualRate: creditAnnualRate,
      creditStartedAt: type == ContainerType.credit ? DateTime.now() : null,
      createdAt: DateTime.now(),
      order: _containers.length,
    );

    await _client.from('containers').insert({
      ...container.toMap(),
      'account_id': CurrentAccount.active.id,
    });

    _containers.add(container);
    notifyListeners();
    return container;
  }

  Future<void> updateContainer(ContainerModel updated) async {
    final index = _containers.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    await _client
        .from('containers')
        .update(updated.toMap())
        .eq('id', updated.id);

    _containers[index] = updated;
    notifyListeners();
  }

  /// 🔹 Définit le compte courant principal
  /// - Un seul possible
  /// - Désactive automatiquement l'ancien
  Future<void> setPrimaryCurrentAccount(String containerId) async {
    final index = _containers.indexWhere((c) => c.id == containerId);
    if (index == -1) return;

    final target = _containers[index];
    if (target.type != ContainerType.currentAccount) return;

    // Désactiver l'ancien principal
    for (int i = 0; i < _containers.length; i++) {
      final c = _containers[i];
      if (c.isPrimary && c.id != target.id) {
        final updated = c.copyWith(isPrimary: false);
        await _client
            .from('containers')
            .update({'is_primary': false}).eq('id', updated.id);
        _containers[i] = updated;
      }
    }

    // Activer le nouveau
    if (!target.isPrimary) {
      final updated = target.copyWith(isPrimary: true);
      await _client
          .from('containers')
          .update({'is_primary': true}).eq('id', updated.id);
      _containers[index] = updated;
    }

    notifyListeners();
  }

  /// Suppression logique :
  /// - hard delete si déjà archivé
  /// - sinon archivage
  Future<void> deleteContainer(String id) async {
    final index = _containers.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final container = _containers[index];

    if (container.isArchived) {
      await _client.from('containers').delete().eq('id', id);
      _containers.removeAt(index);
    } else {
      final archived = container.copyWith(isArchived: true);
      await _client
          .from('containers')
          .update({'is_archived': true}).eq('id', id);
      _containers[index] = archived;
    }

    notifyListeners();
  }

  Future<void> reorderContainers(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || newIndex < 0) return;
    if (oldIndex >= _containers.length || newIndex >= _containers.length) {
      return;
    }

    final item = _containers.removeAt(oldIndex);
    _containers.insert(newIndex, item);

    for (int i = 0; i < _containers.length; i++) {
      _containers[i] = _containers[i].copyWith(order: i);
      await _client
          .from('containers')
          .update({'sort_order': i}).eq('id', _containers[i].id);
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // RESET TOTAL
  // ─────────────────────────────────────────────

  Future<void> clearAll() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client.from('containers').delete().eq('account_id', accountId);
    }
    _containers.clear();
    notifyListeners();
  }
}
