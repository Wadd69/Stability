import 'package:hive/hive.dart';
import 'interest_adjustment.dart';

class InterestAdjustmentsStore {
  static const String _boxName = 'interest_adjustments';

  static late Box _box;
  static final List<InterestAdjustment> _items = [];

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _items
      ..clear()
      ..addAll(
        stored
            .cast<Map>()
            .map(
              (e) => InterestAdjustment.fromMap(
                Map<String, dynamic>.from(e),
              ),
            ),
      );
  }

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────

  static List<InterestAdjustment> get all =>
      List.unmodifiable(_items);

  /// Récupère l’ajustement pour une quinzaine donnée
  static InterestAdjustment? getFor(
    String containerId,
    DateTime quinzaineDate,
  ) {
    try {
      return _items.firstWhere(
        (e) =>
            e.containerId == containerId &&
            e.quinzaineDate == quinzaineDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ajustements non encore injectés dans les transactions
  static List<InterestAdjustment> pendingForContainer(
    String containerId,
  ) {
    return _items
        .where(
          (e) =>
              e.containerId == containerId &&
              e.applied == false,
        )
        .toList();
  }

  // ─────────────────────────────────────────────
  // WRITE
  // ─────────────────────────────────────────────

  static void addOrUpdate(InterestAdjustment adj) {
    final index = _items.indexWhere(
      (e) =>
          e.containerId == adj.containerId &&
          e.quinzaineDate == adj.quinzaineDate,
    );

    if (index == -1) {
      _items.add(adj);
    } else {
      _items[index] = adj;
    }

    _save();
  }

  static void markAsApplied(InterestAdjustment adj) {
    final index = _items.indexWhere(
      (e) =>
          e.containerId == adj.containerId &&
          e.quinzaineDate == adj.quinzaineDate,
    );

    if (index == -1) return;

    _items[index] = adj.copyWith(applied: true);
    _save();
  }

  static void _save() {
    _box.put(
      'list',
      _items.map((e) => e.toMap()).toList(),
    );
  }
}
