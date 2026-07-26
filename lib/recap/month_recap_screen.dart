import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stability/core/finance/finance.dart';
import 'package:stability/core/finance/categories_store.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';

class MonthRecapScreen extends StatefulWidget {
  final String monthLabel;
  final List<Transaction> transactions;

  const MonthRecapScreen({
    super.key,
    required this.monthLabel,
    required this.transactions,
  });

  @override
  State<MonthRecapScreen> createState() => _MonthRecapScreenState();
}

class _MonthRecapScreenState extends State<MonthRecapScreen> {
  bool showPie = true;
  bool asPercentage = false;

  String? focusedCategoryId;
  final Set<String?> selectedCategories = {'__ALL__'};

  // ─────────────────────────
  // 🔒 SOURCE UNIQUE D’ANALYSE
  // Exclut STRICTEMENT les carryOver
  List<Transaction> get _analysisTransactions =>
      widget.transactions.where((t) => !t.isCarryOver).toList();

  // ─────────────────────────
  // COULEURS
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

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analyse – ${widget.monthLabel}'),
        actions: [
          IconButton(
            icon: Text(
              asPercentage ? '%' : '€',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => asPercentage = !asPercentage),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.monthRecap),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showPie) _sunDonut(),
          const SizedBox(height: 24),
          _categoriesAccordion(),
        ],
      ),
    );
  }

  // ─────────────────────────
  // 🌞 SUN DONUT
  Widget _sunDonut() {
    final expenses = _analysisTransactions
        .where((t) => t.type == TransactionType.expense && _allowed(t.category))
        .toList();

    if (expenses.isEmpty) {
      return _card(
        'Dépenses',
        const Center(child: Text('Aucune dépense')),
        220,
      );
    }

    final Map<String?, double> categoryTotals = {};
    for (final t in expenses) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final totalSum =
        categoryTotals.values.fold(0.0, (a, b) => a + b);

    final categories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final details = focusedCategoryId == null
        ? <Transaction>[]
        : expenses
            .where((t) => t.category == focusedCategoryId)
            .toList()
          ..sort((a, b) => a.amount.compareTo(b.amount));

    final detailsSum =
        details.fold(0.0, (a, b) => a + b.amount);

    double minAmount = 0;
    double maxAmount = 0;
    if (details.isNotEmpty) {
      minAmount = details.first.amount;
      maxAmount = details.last.amount;
    }

    return _card(
      focusedCategoryId == null
          ? 'Dépenses par catégorie'
          : 'Dépenses – ${_categoryName(focusedCategoryId)}',
      Column(
        children: [
          if (focusedCategoryId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => focusedCategoryId = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour catégories'),
              ),
            ),
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (focusedCategoryId != null && details.isNotEmpty)
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 85,
                      sectionsSpace: 2,
                      sections: details.map((t) {
                        final ratio =
                            detailsSum == 0 ? 0 : t.amount / detailsSum;
                        final showLabel = ratio > 0.06;

                        return PieChartSectionData(
                          value: t.amount,
                          radius: 78,
                          color: _shadeFromAmount(
                            _baseCategoryColor(focusedCategoryId),
                            t.amount,
                            minAmount,
                            maxAmount,
                          ),
                          title: showLabel
                              ? asPercentage
                                  ? '${t.label}\n${(ratio * 100).toStringAsFixed(1)}%'
                                  : '${t.label}\n${t.amount.toStringAsFixed(0)}€'
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
                          final idx = response!
                              .touchedSection!.touchedSectionIndex;
                          if (idx >= 0 && idx < categories.length) {
                            setState(() {
                              focusedCategoryId =
                                  categories[idx].key;
                            });
                          }
                        }
                      },
                    ),
                    sections: categories.map((e) {
                      final ratio =
                          totalSum == 0 ? 0 : e.value / totalSum;
                      return PieChartSectionData(
                        value: e.value,
                        radius: 70,
                        color:
                            _shade(_baseCategoryColor(e.key), 0.85),
                        title: asPercentage
                            ? '${(ratio * 100).toStringAsFixed(1)}%'
                            : '${e.value.toStringAsFixed(0)}€',
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
                        focusedCategoryId == null
                            ? 'Total'
                            : _categoryName(focusedCategoryId),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        focusedCategoryId == null
                            ? '${totalSum.toStringAsFixed(0)}€'
                            : '${detailsSum.toStringAsFixed(0)}€',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      440,
    );
  }

  // ─────────────────────────
  // ACCORDÉON — ANALYSE UNIQUEMENT
  Widget _categoriesAccordion() {
    final Map<String?, List<Transaction>> grouped = {};

    for (final t in _analysisTransactions) {
      if (!_allowed(t.category)) continue;
      grouped.putIfAbsent(t.category, () => []).add(t);
    }

    return Column(
      children: grouped.entries.map((e) {
        final color = _baseCategoryColor(e.key);

        return Card(
          child: ExpansionTile(
            leading: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(_categoryName(e.key)),
            children: e.value.map(_transactionTile).toList(),
          ),
        );
      }).toList(),
    );
  }

  ListTile _transactionTile(Transaction t) {
    final isIncome = t.type == TransactionType.income;

    return ListTile(
      title: Text(t.label),
      trailing: Text(
        '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)}€',
        style: TextStyle(
          color: isIncome ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _allowed(String? id) =>
      selectedCategories.contains('__ALL__') ||
      selectedCategories.contains(id);

  String _categoryName(String? id) =>
      id == null
          ? 'Sans catégorie'
          : CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';

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
              Text(title,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
