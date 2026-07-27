import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/finance/categories_store.dart';
import '../core/finance/transaction.dart';
import '../core/finance/transaction_type.dart';

enum PieChartMode { expenses, income, both }

/// Sélecteur Dépenses / Entrées / Les deux, à placer près du camembert.
class PieChartModeSelector extends StatelessWidget {
  final PieChartMode value;
  final ValueChanged<PieChartMode> onChanged;

  const PieChartModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Dépenses'),
          selected: value == PieChartMode.expenses,
          onSelected: (_) => onChanged(PieChartMode.expenses),
        ),
        ChoiceChip(
          label: const Text('Entrées'),
          selected: value == PieChartMode.income,
          onSelected: (_) => onChanged(PieChartMode.income),
        ),
        ChoiceChip(
          label: const Text('Les deux'),
          selected: value == PieChartMode.both,
          onSelected: (_) => onChanged(PieChartMode.both),
        ),
      ],
    );
  }
}

/// Identifie une part du camembert : une catégorie pour un type de
/// mouvement donné. En mode "Les deux", une même catégorie peut apparaître
/// deux fois (une part dépenses, une part entrées) dans le MÊME camembert.
class _SliceKey {
  final String? categoryId;
  final TransactionType type;

  const _SliceKey(this.categoryId, this.type);

  @override
  bool operator ==(Object other) =>
      other is _SliceKey && other.categoryId == categoryId && other.type == type;

  @override
  int get hashCode => Object.hash(categoryId, type);
}

/// Camembert par catégorie avec drill-down (identique au "sun donut"
/// précédemment dupliqué dans month_recap_screen, month_archive_screen,
/// year_charts_screen et global_history_line_chart). Reçoit une liste déjà
/// filtrée par l'écran appelant (catégories sélectionnées, période, etc.).
/// En mode [PieChartMode.both], dépenses et entrées apparaissent dans le
/// même camembert (parts plus claires pour les entrées, plus foncées pour
/// les dépenses) plutôt que dans deux camemberts séparés.
class CategoryPieChart extends StatefulWidget {
  final List<Transaction> transactions;
  final PieChartMode mode;
  final bool asPercentage;
  final String currencySymbol;

  const CategoryPieChart({
    super.key,
    required this.transactions,
    required this.mode,
    this.asPercentage = false,
    this.currencySymbol = '€',
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  _SliceKey? _focused;

  @override
  void didUpdateWidget(covariant CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _focused = null;
    }
  }

  Color _baseCategoryColor(String? id) {
    if (id == null) return Colors.grey;
    final c = CategoriesStore.getById(id);
    return c == null ? Colors.grey : Color(c.colorValue);
  }

  Color _shade(Color base, double t) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness - (0.45 * t)).clamp(0.18, 0.85))
        .toColor();
  }

  Color _shadeFromAmount(Color base, double amount, double min, double max) {
    if (max <= min) return _shade(base, 0.85);
    final normalized = (amount - min) / (max - min);
    final t = (0.2 + 0.8 * normalized).clamp(0.0, 1.0);
    return _shade(base, t);
  }

  /// Éclaircit une couleur pour les entrées, afin de les distinguer des
  /// dépenses (même teinte de catégorie) sans changer de palette.
  Color _tintForType(Color base, TransactionType type) {
    return type == TransactionType.income
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.4), base)
        : base;
  }

  String _categoryName(String? id) => id == null
      ? 'Sans catégorie'
      : CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';

  String _sign(TransactionType type) =>
      type == TransactionType.income ? '+' : '−';

  Widget _card(String title, Widget child, double height) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.transactions
        .where((t) =>
            t.type == TransactionType.expense || t.type == TransactionType.income)
        .where((t) => switch (widget.mode) {
              PieChartMode.expenses => t.type == TransactionType.expense,
              PieChartMode.income => t.type == TransactionType.income,
              PieChartMode.both => true,
            })
        .toList();

    final title = switch (widget.mode) {
      PieChartMode.expenses => 'Dépenses',
      PieChartMode.income => 'Entrées',
      PieChartMode.both => 'Entrées et dépenses',
    };
    final emptyMessage = switch (widget.mode) {
      PieChartMode.expenses => 'Aucune dépense',
      PieChartMode.income => 'Aucune entrée',
      PieChartMode.both => 'Aucun mouvement',
    };

    if (items.isEmpty) {
      return _card(title, Center(child: Text(emptyMessage)), 220);
    }

    final Map<_SliceKey, double> totals = {};
    for (final t in items) {
      final key = _SliceKey(t.category, t.type);
      totals[key] = (totals[key] ?? 0) + t.amount;
    }

    final totalSum = totals.values.fold(0.0, (a, b) => a + b);
    final slices = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final details = _focused == null
        ? <Transaction>[]
        : (items
            .where((t) => t.category == _focused!.categoryId && t.type == _focused!.type)
            .toList()
          ..sort((a, b) => a.amount.compareTo(b.amount)));

    final detailsSum = details.fold(0.0, (a, b) => a + b.amount);

    double minAmount = 0;
    double maxAmount = 0;
    if (details.isNotEmpty) {
      minAmount = details.first.amount;
      maxAmount = details.last.amount;
    }

    final focused = _focused;

    return _card(
      focused == null
          ? '$title par catégorie'
          : '${_sign(focused.type)} ${_categoryName(focused.categoryId)}',
      Column(
        children: [
          if (focused != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _focused = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour catégories'),
              ),
            ),
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (focused != null && details.isNotEmpty)
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 85,
                      sectionsSpace: 2,
                      sections: details.map((t) {
                        final ratio = detailsSum == 0 ? 0 : t.amount / detailsSum;
                        final showLabel = ratio > 0.06;

                        return PieChartSectionData(
                          value: t.amount,
                          radius: 78,
                          color: _tintForType(
                            _shadeFromAmount(
                              _baseCategoryColor(focused.categoryId),
                              t.amount,
                              minAmount,
                              maxAmount,
                            ),
                            focused.type,
                          ),
                          title: showLabel
                              ? widget.asPercentage
                                  ? '${t.label}\n${(ratio * 100).toStringAsFixed(1)}%'
                                  : '${t.label}\n${t.amount.toStringAsFixed(0)}${widget.currencySymbol}'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          titlePositionPercentageOffset: 0.6,
                        );
                      }).toList(),
                    ),
                  ),
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent &&
                            response?.touchedSection != null) {
                          final idx = response!.touchedSection!.touchedSectionIndex;
                          if (idx >= 0 && idx < slices.length) {
                            setState(() => _focused = slices[idx].key);
                          }
                        }
                      },
                    ),
                    sections: slices.map((e) {
                      final ratio = totalSum == 0 ? 0 : e.value / totalSum;
                      final label = widget.asPercentage
                          ? '${(ratio * 100).toStringAsFixed(1)}%'
                          : '${e.value.toStringAsFixed(0)}${widget.currencySymbol}';
                      return PieChartSectionData(
                        value: e.value,
                        radius: 70,
                        color: _tintForType(
                          _shade(_baseCategoryColor(e.key.categoryId), 0.85),
                          e.key.type,
                        ),
                        title: widget.mode == PieChartMode.both
                            ? '${_sign(e.key.type)}$label'
                            : label,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        focused == null ? 'Total' : _categoryName(focused.categoryId),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        focused == null
                            ? '${totalSum.toStringAsFixed(0)}${widget.currencySymbol}'
                            : '${detailsSum.toStringAsFixed(0)}${widget.currencySymbol}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.mode == PieChartMode.both && focused == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Teinte claire = entrée · teinte foncée = dépense',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      widget.mode == PieChartMode.both && focused == null ? 460 : 440,
    );
  }
}
