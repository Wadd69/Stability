import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stability/core/finance/transaction_type.dart';

import '../../core/archives/archives_store.dart';
import '../../core/archives/archived_month.dart';
import '../../core/finance/categories_store.dart';
import '../../core/finance/transaction.dart';
import '../../core/finance/transactions_store.dart';
import '../../theme/app_colors.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../shared/category_pie_chart.dart';

class GlobalHistoryLineChartScreen extends StatefulWidget {
  const GlobalHistoryLineChartScreen({super.key});

  @override
  State<GlobalHistoryLineChartScreen> createState() =>
      _GlobalHistoryLineChartScreenState();
}

class _GlobalHistoryLineChartScreenState
    extends State<GlobalHistoryLineChartScreen> {
  // Affichage
  bool showLineChart = false;
  bool showDonut = false;

  // Donut
  bool donutAsPercentage = false;
  PieChartMode pieMode = PieChartMode.expenses;

  // Courbe
  bool showTotalExpenses = true;
  bool showTotalIncome = true;
  bool showLineFilters = false;
  final Set<String?> visibleLineCategories = {};

  // Filtre global
  final Set<String?> selectedCategories = {'__ALL__'};

  final String _currencySymbol = '€';

  // ─────────────────────────
  // COULEURS (IDENTIQUES Month / Year)
  Color _baseCategoryColor(String? id) {
    if (id == null) return Colors.grey;
    final c = CategoriesStore.getById(id);
    return c == null ? Colors.grey : Color(c.colorValue);
  }

  // ─────────────────────────
  List<ArchivedMonth> get _months {
    final m = List<ArchivedMonth>.from(ArchivesStore.all)
      ..sort((a, b) =>
          (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
    return m;
  }

  List<Transaction> get _allTransactions => _months
      .expand((m) => TransactionsStore.archivedForMonth(m.id))
      .toList();

  bool _allowed(String? id) =>
      selectedCategories.contains('__ALL__') ||
      selectedCategories.contains(id);

  @override
  void initState() {
    super.initState();
    for (final c in CategoriesStore.all) {
      visibleLineCategories.add(c.id);
    }
  }

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_months.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Historique global'),
          actions: [_helpAction()],
        ),
        body: const Center(child: Text('Aucune archive disponible')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique global'),
        actions: [
          _toggleIcon(
            icon: Icons.show_chart,
            active: showLineChart,
            tooltip: 'Courbe',
            onTap: () => setState(() => showLineChart = !showLineChart),
          ),
          _toggleIcon(
            icon: Icons.donut_large,
            active: showDonut,
            tooltip: 'Donut',
            onTap: () => setState(() => showDonut = !showDonut),
          ),
          if (showDonut)
            IconButton(
              icon: Text(
                donutAsPercentage ? '%' : _currencySymbol,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () =>
                  setState(() => donutAsPercentage = !donutAsPercentage),
            ),
          _helpAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!showLineChart && !showDonut)
            _card(
              'Analyse',
              const Center(
                child: Text(
                  'Active “Courbe” ou “Donut” pour analyser l’historique.',
                ),
              ),
              180,
            ),
          if (showLineChart) _globalLineChart(),
          if (showLineChart && showDonut) const SizedBox(height: 24),
          if (showDonut) ...[
            PieChartModeSelector(
              value: pieMode,
              onChanged: (m) => setState(() => pieMode = m),
            ),
            const SizedBox(height: 12),
            CategoryPieChart(
              transactions: _allTransactions.where((t) => _allowed(t.category)).toList(),
              mode: pieMode,
              asPercentage: donutAsPercentage,
              currencySymbol: _currencySymbol,
            ),
          ],
          const SizedBox(height: 24),
          _categoriesAccordion(),
        ],
      ),
    );
  }

  Widget _helpAction() {
    return IconButton(
      tooltip: 'Aide',
      icon: const Icon(Icons.help_outline),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HelpScreen(topic: HelpTopic.globalHistory),
          ),
        );
      },
    );
  }

  // ─────────────────────────
  // 📈 COURBE GLOBALE (AXE Y ADAPTATIF)
  Widget _globalLineChart() {
    final totalsExpenses = <double>[];
    final totalsIncome = <double>[];

    final Map<String?, List<double>> perCategory = {};
    for (final c in CategoriesStore.all) {
      perCategory[c.id] = [];
    }

    for (final m in _months) {
      double exp = 0;
      double inc = 0;

      for (final t in TransactionsStore.archivedForMonth(m.id)) {
        if (!_allowed(t.category)) continue;

        perCategory.putIfAbsent(t.category, () => []);
        if (perCategory[t.category]!.length < totalsExpenses.length + 1) {
          perCategory[t.category]!.add(0);
        }
        perCategory[t.category]!.last += t.amount;

        if (t.type == TransactionType.expense) {
          exp += t.amount;
        } else {
          inc += t.amount;
        }
      }

      totalsExpenses.add(exp);
      totalsIncome.add(inc);
    }

    final List<LineChartBarData> lines = [];

    if (showTotalIncome) {
      lines.add(_buildLine(totalsIncome, Colors.grey.shade300, 3));
    }
    if (showTotalExpenses) {
      lines.add(_buildLine(totalsExpenses, Colors.grey.shade800, 3.5));
    }

    for (final e in perCategory.entries) {
      if (!visibleLineCategories.contains(e.key)) continue;
      lines.add(_buildLine(e.value, _baseCategoryColor(e.key), 2));
    }

    // 🔥 CALCUL AXE Y DYNAMIQUE
    final allY = <double>[];
    for (final l in lines) {
      for (final s in l.spots) {
        allY.add(s.y);
      }
    }

    double maxY =
        allY.isEmpty ? 0 : allY.reduce((a, b) => a > b ? a : b);

    double padding;
    if (maxY < 5000) {
      padding = 500;
    } else if (maxY < 20000) {
      padding = 1000;
    } else {
      padding = maxY * 0.1;
    }

    final adaptedMaxY = maxY + padding;

    return _card(
      'Évolution globale',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lineHeaderControls(),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: adaptedMaxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(0)}$_currencySymbol',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _months.length) {
                          return const SizedBox.shrink();
                        }
                        final m = _months[i];
                        return Text(
                          '${m.month}/${m.year}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: lines,
              ),
            ),
          ),
          if (showLineFilters) ...[
            const SizedBox(height: 12),
            _lineFiltersPanel(),
          ],
        ],
      ),
      showLineFilters ? 520 : 420,
    );
  }

  LineChartBarData _buildLine(
      List<double> values, Color color, double width) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      barWidth: width,
      color: color,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _lineHeaderControls() {
    return Row(
      children: [
        const Text('Courbes', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => showLineFilters = !showLineFilters),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Filtres'),
        ),
      ],
    );
  }

  Widget _lineFiltersPanel() {
    final cats = CategoriesStore.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cats.map((c) {
        final selected = visibleLineCategories.contains(c.id);
        return _pill(
          label: c.name,
          selected: selected,
          color: Color(c.colorValue),
          onTap: () => setState(() {
            selected
                ? visibleLineCategories.remove(c.id)
                : visibleLineCategories.add(c.id);
          }),
        );
      }).toList(),
    );
  }

  // ─────────────────────────
  // ACCORDÉON
  Widget _categoriesAccordion() {
    final Map<String?, List<Transaction>> grouped = {};
    for (final t in _allTransactions) {
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
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
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
        '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)}$_currencySymbol',
        style: TextStyle(
          color: isIncome ? context.appColors.positive : context.appColors.negative,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _categoryName(String? id) => id == null
      ? 'Sans catégorie'
      : CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';

  Widget _toggleIcon({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon,
          color: active ? Theme.of(context).colorScheme.primary : null),
      onPressed: onTap,
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          color: selected ? scheme.primaryContainer : Colors.transparent,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ]),
      ),
    );
  }

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
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
