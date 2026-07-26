import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'container_model.dart';
import 'container_type.dart';

class ContainersStore extends ChangeNotifier {
  static const String _boxName = 'containers_box';

  late Box _box;
  final List<ContainerModel> _containers = [];

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────

  List<ContainerModel> get all =>
      List.unmodifiable(_containers);

  List<ContainerModel> get active =>
      _containers
          .where((c) => !c.isArchived)
          .toList()
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

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadFromBox();
  }

  void _loadFromBox() {
    _containers
      ..clear()
      ..addAll(
        _box.values.map(
          (e) => ContainerModel.fromMap(
            Map<dynamic, dynamic>.from(e),
          ),
        ),
      );

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────

  ContainerModel createContainer({
    required String name,
    required int colorValue,
    required ContainerType type,
    List<InterestRatePeriod>? interestRates,
  }) {
    final container = ContainerModel(
      id: UniqueKey().toString(),
      name: name,
      colorValue: colorValue,
      type: type,
      interestRates: interestRates ?? [],
      createdAt: DateTime.now(),
      order: _containers.length,
    );

    _containers.add(container);
    _persist(container);
    notifyListeners();
    return container;
  }

  void updateContainer(ContainerModel updated) {
    final index = _containers.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    _containers[index] = updated;
    _persist(updated);
    notifyListeners();
  }

  /// 🔹 Définit le compte courant principal
  /// - Un seul possible
  /// - Désactive automatiquement l’ancien
  void setPrimaryCurrentAccount(String containerId) {
    final index = _containers.indexWhere((c) => c.id == containerId);
    if (index == -1) return;

    final target = _containers[index];

    if (target.type != ContainerType.currentAccount) {
      return;
    }

    // Désactiver l’ancien principal
    for (int i = 0; i < _containers.length; i++) {
      final c = _containers[i];
      if (c.isPrimary && c.id != target.id) {
        _containers[i] = c.copyWith(isPrimary: false);
        _persist(_containers[i]);
      }
    }

    // Activer le nouveau
    if (!target.isPrimary) {
      final updated = target.copyWith(isPrimary: true);
      _containers[index] = updated;
      _persist(updated);
    }

    notifyListeners();
  }

  /// Suppression logique :
  /// - hard delete si déjà archivé
  /// - sinon archivage
  void deleteContainer(String id) {
    final index = _containers.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final container = _containers[index];

    if (container.isArchived) {
      _containers.removeAt(index);
      _box.delete(container.id);
    } else {
      final archived = container.copyWith(isArchived: true);
      _containers[index] = archived;
      _persist(archived);
    }

    notifyListeners();
  }

  void reorderContainers(int oldIndex, int newIndex) {
    if (oldIndex < 0 || newIndex < 0) return;
    if (oldIndex >= _containers.length ||
        newIndex >= _containers.length) {
      return;
    }

    final item = _containers.removeAt(oldIndex);
    _containers.insert(newIndex, item);

    for (int i = 0; i < _containers.length; i++) {
      _containers[i] = _containers[i].copyWith(order: i);
      _persist(_containers[i]);
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // RESET TOTAL
  // ─────────────────────────────────────────────

  void clearAll() {
    _containers.clear();
    _box.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // PERSISTENCE
  // ─────────────────────────────────────────────

  void _persist(ContainerModel container) {
    _box.put(container.id, container.toMap());
  }
}
