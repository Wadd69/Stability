import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stability/core/finance/transaction_type.dart';

import '../../core/archives/archived_month.dart';
import '../../core/finance/transaction.dart';
import '../../core/finance/transactions_store.dart';
import '../../core/finance/categories_store.dart';
import '../../theme/app_colors.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../shared/category_pie_chart.dart';

class YearChartsScreen extends StatefulWidget {
  final int year;
  final List<ArchivedMonth> months;

  const YearChartsScreen({
    super.key,
    required this.year,
    required this.months,
  });

  @override
  State<YearChartsScreen> createState() => _YearChartsScreenState();
}

class _YearChartsScreenState extends State<YearChartsScreen> {
  // Toggle % / montant — ⚠️ UTILISÉ UNIQUEMENT PAR LE DONUT
  bool asPercentage = false;

  // Affichage contrôlé par l’utilisateur
  bool showLineChart = false;
  bool showDonut = false;

  // Donut
  PieChartMode pieMode = PieChartMode.expenses;

  // Filtre global (donut + accordéon)
  final Set<String?> selectedCategories = {'__ALL__'};

  // Courbe — filtres
  bool showTotalExpenses = true;
  bool showTotalIncome = true;
  bool showLineFilters = false;
  final Set<String?> visibleLineCategories = {};

  // Devise temporaire
  final String _currencySymbol = '€';

  // ─────────────────────────
  // COULEURS (IDENTIQUES MonthRecap)
  Color _baseCategoryColor(String? id) {
    if (id == null) return Colors.grey;
    final c = CategoriesStore.getById(id);
    return c == null ? Colors.grey : Color(c.colorValue);
  }

  // ─────────────────────────
  List<Transaction> get _allTransactions {
    return widget.months
        .expand<Transaction>(
          (ArchivedMonth m) => TransactionsStore.archivedForMonth(m.id),
        )
        .toList();
  }

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

  // Mois -> index 0..11
  int _monthIndex(ArchivedMonth m, int fallbackOrderIndex) {
    final int raw = m.month;
    if (raw >= 1 && raw <= 12) return raw - 1;
    return fallbackOrderIndex.clamp(0, 11);
  }

  String _fmtAmount(double v) => '${v.toStringAsFixed(0)}$_currencySymbol';

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analyse – ${widget.year}'),
        actions: [
          _appBarToggleIcon(
            tooltip: 'Courbe',
            icon: Icons.show_chart,
            selected: showLineChart,
            onTap: () => setState(() => showLineChart = !showLineChart),
          ),
          _appBarToggleIcon(
            tooltip: 'Donut',
            icon: Icons.donut_large,
            selected: showDonut,
            onTap: () => setState(() => showDonut = !showDonut),
          ),
          const SizedBox(width: 6),
          // ⚠️ Bouton % / € : N’AFFECTE QUE LE DONUT
          IconButton(
            icon: Text(
              asPercentage ? '%' : _currencySymbol,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => setState(() => asPercentage = !asPercentage),
            tooltip: asPercentage ? 'Afficher en montant' : 'Afficher en %',
          ),
          IconButton(
            tooltip: 'Aide',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.archiveDetail),
                ),
              );
            },
          ),
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
                  'Active “Courbe” ou “Donut” en haut à droite pour analyser l’année.',
                ),
              ),
              180,
            ),
          if (showLineChart) _yearLineChart(), // ← montants uniquement
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
              asPercentage: asPercentage,
              currencySymbol: _currencySymbol,
            ),
          ],
          const SizedBox(height: 24),
          _categoriesAccordion(),
        ],
      ),
    );
  }

  Widget _appBarToggleIcon({
    required String tooltip,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: 1,
            ),
            color: selected ? scheme.primaryContainer : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────
  // 📈 COURBE ANNUELLE — MONTANTS UNIQUEMENT (PAS DE %)
  Widget _yearLineChart() {
    final totalsExpenses = List<double>.filled(12, 0);
    final totalsIncome = List<double>.filled(12, 0);

    final Map<String?, List<double>> perCategory = {};

    for (final c in CategoriesStore.all) {
      perCategory.putIfAbsent(c.id, () => List<double>.filled(12, 0));
    }

    for (int i = 0; i < widget.months.length; i++) {
      final m = widget.months[i];
      final mi = _monthIndex(m, i);

      for (final t in TransactionsStore.archivedForMonth(m.id)) {
        perCategory.putIfAbsent(t.category, () => List<double>.filled(12, 0));
        perCategory[t.category]![mi] += t.amount;

        if (t.type == TransactionType.expense) {
          totalsExpenses[mi] += t.amount;
        } else {
          totalsIncome[mi] += t.amount;
        }
      }
    }

    final List<LineChartBarData> lines = [];

    // Revenus d’abord
    if (showTotalIncome) {
      lines.add(_buildLine(
        totalsIncome,
        Colors.grey.shade300,
        width: 3,
      ));
    }

    // Dépenses en dernier (au-dessus)
    if (showTotalExpenses) {
      lines.add(_buildLine(
        totalsExpenses,
        Colors.grey.shade800,
        width: 3.5,
      ));
    }

    final entries = perCategory.entries.toList()
      ..sort((a, b) => _categoryName(a.key).compareTo(_categoryName(b.key)));

    for (final e in entries) {
      if (!visibleLineCategories.contains(e.key)) continue;
      lines.add(_buildLine(
        e.value,
        _baseCategoryColor(e.key),
        width: 2,
      ));
    }

    final allY = <double>[];
    for (final l in lines) {
      for (final s in l.spots) {
        allY.add(s.y);
      }
    }
    final minY = allY.isEmpty ? 0.0 : allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.isEmpty ? 0.0 : allY.reduce((a, b) => a > b ? a : b);

    final paddedMinY = (minY * 0.9).clamp(0.0, double.infinity);
    final paddedMaxY = (maxY * 1.1).clamp(0.0, double.infinity);
    final safeMaxY = paddedMaxY == paddedMinY ? paddedMinY + 1 : paddedMaxY;

    return _card(
      'Évolution mensuelle',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lineHeaderControls(),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: paddedMinY,
                maxY: safeMaxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _niceInterval(safeMaxY),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        return LineTooltipItem(
                          _fmtAmount(s.y),
                          const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: _niceInterval(safeMaxY),
                      getTitlesWidget: (v, meta) => Text(
                        _fmtAmount(v),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        const labels = [
                          'J','F','M','A','M','J','J','A','S','O','N','D'
                        ];
                        final i = v.toInt();
                        if (i < 0 || i > 11) return const SizedBox.shrink();
                        return Text(
                          labels[i],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _lineHeaderControls() {
    return Row(
      children: [
        Text(
          'Courbes',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => showLineFilters = !showLineFilters),
          icon: Icon(showLineFilters ? Icons.expand_less : Icons.tune, size: 18),
          label: Text(showLineFilters ? 'Masquer filtres' : 'Filtres'),
        ),
      ],
    );
  }

  Widget _lineFiltersPanel() {
    final cats = CategoriesStore.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _proTogglePill(
              label: 'Total Dépenses',
              selected: showTotalExpenses,
              colorDot: Colors.grey.shade800,
              onTap: () => setState(() => showTotalExpenses = !showTotalExpenses),
            ),
            _proTogglePill(
              label: 'Total Revenus',
              selected: showTotalIncome,
              colorDot: Colors.grey.shade300,
              onTap: () => setState(() => showTotalIncome = !showTotalIncome),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cats.map((c) {
            final selected = visibleLineCategories.contains(c.id);
            final dot = Color(c.colorValue);
            return _proTogglePill(
              label: c.name,
              selected: selected,
              colorDot: dot,
              onTap: () => setState(() {
                if (selected) {
                  visibleLineCategories.remove(c.id);
                } else {
                  visibleLineCategories.add(c.id);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _proTogglePill({
    required String label,
    required bool selected,
    required Color colorDot,
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
            width: 1,
          ),
          color: selected ? scheme.primaryContainer : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colorDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 2000) return 250;
    if (maxY <= 10000) return 1000;
    return 2500;
  }

  LineChartBarData _buildLine(
    List<double> values,
    Color color, {
    double width = 2,
  }) {
    final spots = List.generate(
      12,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    return LineChartBarData(
      spots: spots, // ← PAS DE %
      isCurved: true,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
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
