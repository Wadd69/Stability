import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../core/comparison/comparison_period.dart';
import '../../core/containers/containers_store.dart';
import '../../core/finance/categories_store.dart';
import '../../core/finance/transaction.dart';
import '../../core/finance/transaction_analysis.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

enum _CurveMetric { balance, income, expense } // ✅ AJOUT (courbe pro)

class ComparisonHubScreen extends StatefulWidget {
  final List<ComparisonPeriod> periods;

  const ComparisonHubScreen({
    super.key,
    required this.periods,
  });

  @override
  State<ComparisonHubScreen> createState() => _ComparisonHubScreenState();
}

class _ComparisonHubScreenState extends State<ComparisonHubScreen> {
  // Affichage
  bool showCurve = true;
  bool showDonut = false;

  // ✅ AJOUT (courbe pro)
  _CurveMetric curveMetric = _CurveMetric.balance;

  // Donut
  bool donutAsPercentage = false;
  ComparisonPeriod? selectedPeriod;
  String? focusedCategoryId;

  // Filtre global (donut)
  final Set<String?> selectedCategories = {'__ALL__'};

  final String _currency = '€';

  // ─────────────────────────
  // 🎨 COULEURS (IDENTIQUES MonthRecap)
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
    final n = (amount - min) / (max - min);
    return _shade(base, (0.2 + 0.8 * n).clamp(0, 1));
  }

  bool _allowed(String? id) =>
      selectedCategories.contains('__ALL__') || selectedCategories.contains(id);

  String _categoryName(String? id) => id == null
      ? 'Sans catégorie'
      : CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';

  @override
  void initState() {
    super.initState();
    // Sélection auto par défaut (UX)
    if (widget.periods.isNotEmpty) {
      selectedPeriod = widget.periods.first;
    }
  }

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison'),
        actions: [
          _toggleIcon(
            icon: Icons.show_chart,
            active: showCurve,
            tooltip: 'Courbe',
            onTap: () => setState(() {
              showCurve = !showCurve;
              if (showCurve) showDonut = false;
            }),
          ),
          _toggleIcon(
            icon: Icons.donut_large,
            active: showDonut,
            tooltip: 'Donut',
            onTap: () => setState(() {
              showDonut = !showDonut;
              if (showDonut) showCurve = false;
            }),
          ),

          // Toggle % / €
          if (showDonut)
            IconButton(
              icon: Text(
                donutAsPercentage ? '%' : _currency,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () =>
                  setState(() => donutAsPercentage = !donutAsPercentage),
              tooltip:
                  donutAsPercentage ? 'Afficher en montant' : 'Afficher en %',
            ),

          // Filtres donut
          if (showDonut)
            IconButton(
              tooltip: 'Filtres',
              icon: const Icon(Icons.tune),
              onPressed: _openDonutFilters,
            ),

          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.comparison),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // ─────────────────────────
  Widget _buildBody() {
    if (!showCurve && !showDonut) {
      return const Center(
        child: Text(
          'Sélectionne un mode d’analyse',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (showCurve) {
      return _curveView();
    }

    return _donutView();
  }

  // ─────────────────────────────────────────────
  // 📈 COURBE (BRANCHÉE — plus de placeholder)
  // ─────────────────────────────────────────────
  Widget _curveView() {
    final periods = widget.periods;

    if (periods.isEmpty) {
      return const Center(child: Text('Aucune période sélectionnée'));
    }

    // Spots
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < periods.length; i++) {
      final p = periods[i];
      final y = switch (curveMetric) {
        _CurveMetric.balance => p.balance,
        _CurveMetric.income => p.totalIncome,
        _CurveMetric.expense => p.totalExpense,
      };

      spots.add(FlSpot(i.toDouble(), y));
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (minY == maxY) {
      minY -= 100;
      maxY += 100;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }

    final lineColor = switch (curveMetric) {
      _CurveMetric.balance => Theme.of(context).colorScheme.primary,
      _CurveMetric.income => context.appColors.positive,
      _CurveMetric.expense => context.appColors.negative,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          'Comparaison — ${_metricLabel()}',
          LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: const FlDotData(show: true),
                  barWidth: 3,
                  color: lineColor,
                ),
              ],
            ),
          ),
          260,
        ),
        const SizedBox(height: 12),

        // ✅ Sélecteur métrique (pro + UX simple)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _metricButton(_CurveMetric.balance, 'Solde'),
            _metricButton(_CurveMetric.income, 'Revenus'),
            _metricButton(_CurveMetric.expense, 'Dépenses'),
          ],
        ),

        const SizedBox(height: 12),
        ...periods.map(_periodSummary),
      ],
    );
  }

  String _metricLabel() {
    return switch (curveMetric) {
      _CurveMetric.balance => 'Solde',
      _CurveMetric.income => 'Revenus',
      _CurveMetric.expense => 'Dépenses',
    };
  }

  Widget _metricButton(_CurveMetric m, String label) {
    final active = curveMetric == m;
    return OutlinedButton(
      onPressed: () => setState(() => curveMetric = m),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            active ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }

  Widget _periodSummary(ComparisonPeriod p) {
    return Card(
      child: ListTile(
        title: Text(p.label),
        subtitle: Text(
          'Revenus : ${p.totalIncome.toStringAsFixed(0)}$_currency • '
          'Dépenses : ${p.totalExpense.toStringAsFixed(0)}$_currency',
        ),
        trailing: Text(
          '${p.balance.toStringAsFixed(0)}$_currency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: p.balance >= 0
                ? context.appColors.positive
                : context.appColors.negative,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🌞 DONUT — IDENTIQUE MonthRecap + filtres (INCHANGÉ)
  // ─────────────────────────────────────────────
  Widget _donutView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<ComparisonPeriod>(
            initialValue: selectedPeriod,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(),
            ),
            items: widget.periods.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p.label),
              );
            }).toList(),
            onChanged: (p) {
              setState(() {
                selectedPeriod = p;
                focusedCategoryId = null;
              });
            },
          ),
        ),

        // Petit rappel filtre actif (pro UX)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniFilterChip(
                  label: selectedCategories.contains('__ALL__')
                      ? 'Toutes catégories'
                      : '${selectedCategories.length} catégories',
                  onTap: _openDonutFilters,
                ),
                if (!selectedCategories.contains('__ALL__') &&
                    selectedCategories.contains(null))
                  _miniFilterChip(
                    label: 'Sans catégorie',
                    onTap: _openDonutFilters,
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: selectedPeriod == null
              ? const Center(
                  child: Text(
                    'Sélectionne une période pour analyser',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sunDonutForPeriod(selectedPeriod!),
                    const SizedBox(height: 16),
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
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sunDonutForPeriod(ComparisonPeriod period) {
    final containersStore = context.read<ContainersStore>();
    final expenses = period.transactions
        .where((t) =>
            TransactionAnalysis.countsAsExpense(
                t, period.transactions, containersStore) &&
            _allowed(t.category))
        .toList();

    if (expenses.isEmpty) {
      return _card(
        'Dépenses',
        const Center(child: Text('Aucune dépense')),
        220,
      );
    }

    final Map<String?, double> totals = {};
    for (final t in expenses) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }

    final totalSum = totals.values.fold(0.0, (a, b) => a + b);

    final cats = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final details = focusedCategoryId == null
        ? <Transaction>[]
        : expenses.where((t) => t.category == focusedCategoryId).toList();

    final detailsSum = details.fold(0.0, (a, b) => a + b.amount);

    double min = 0, max = 0;
    if (details.isNotEmpty) {
      details.sort((a, b) => a.amount.compareTo(b.amount));
      min = details.first.amount;
      max = details.last.amount;
    }

    return _card(
      focusedCategoryId == null
          ? 'Répartition des dépenses'
          : _categoryName(focusedCategoryId),
      SizedBox(
        height: 320,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Rayons fixes en pixels côté fl_chart (jamais réduits tout
            // seuls) : sur un téléphone étroit, l'anneau de détail (le plus
            // grand) dépasserait la largeur disponible et serait rogné par
            // le Stack. Facteur d'échelle commun pour rester dans le cadre.
            const baseCenterSpace = 40.0;
            const baseRadius = 70.0;
            const focusedCenterSpace = 90.0;
            const focusedRadius = 80.0;
            final neededDiameter = focusedCategoryId != null
                ? (focusedCenterSpace + focusedRadius) * 2
                : (baseCenterSpace + baseRadius) * 2;
            final scale = constraints.maxWidth <= 0
                ? 1.0
                : (constraints.maxWidth / neededDiameter).clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // ── anneau extérieur : transactions (si focus catégorie)
                if (focusedCategoryId != null && details.isNotEmpty)
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: focusedCenterSpace * scale,
                      sectionsSpace: 2,
                      sections: details.map((t) {
                        final ratio =
                            detailsSum == 0 ? 0 : t.amount / detailsSum;
                        final showLabel = ratio > 0.06;

                        return PieChartSectionData(
                          value: t.amount,
                          radius: focusedRadius * scale,
                          color: _shadeFromAmount(
                            _baseCategoryColor(focusedCategoryId),
                            t.amount,
                            min,
                            max,
                          ),
                          title: showLabel
                              ? donutAsPercentage
                                  ? '${t.label}\n${(ratio * 100).toStringAsFixed(1)}%'
                                  : '${t.label}\n${t.amount.toStringAsFixed(0)}$_currency'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          titlePositionPercentageOffset: 0.62,
                        );
                      }).toList(),
                    ),
                  ),

                // ── anneau intérieur : catégories
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: baseCenterSpace * scale,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent &&
                            response?.touchedSection != null) {
                          final idx =
                              response!.touchedSection!.touchedSectionIndex;
                          if (idx >= 0 && idx < cats.length) {
                            setState(() {
                              focusedCategoryId = cats[idx].key;
                            });
                          }
                        }
                      },
                    ),
                    sections: cats.map((e) {
                      final ratio = totalSum == 0 ? 0 : e.value / totalSum;
                      return PieChartSectionData(
                        value: e.value,
                        radius: baseRadius * scale,
                        color: _shade(_baseCategoryColor(e.key), 0.85),
                        title: donutAsPercentage
                            ? '${(ratio * 100).toStringAsFixed(1)}%'
                            : '${e.value.toStringAsFixed(0)}$_currency',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        titlePositionPercentageOffset: 0.62,
                      );
                    }).toList(),
                  ),
                ),

                // ── centre
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        focusedCategoryId == null
                            ? 'Total'
                            : _categoryName(focusedCategoryId),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        focusedCategoryId == null
                            ? '${totalSum.toStringAsFixed(0)}$_currency'
                            : '${detailsSum.toStringAsFixed(0)}$_currency',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      460,
    );
  }

  // ─────────────────────────
  // 🎛 FILTRES DONUT (INCHANGÉ)
  void _openDonutFilters() {
    final cats = CategoriesStore.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Filtrer les catégories',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Toutes les catégories'),
                value: selectedCategories.contains('__ALL__'),
                onChanged: (v) {
                  setState(() {
                    selectedCategories
                      ..clear()
                      ..add('__ALL__');
                    focusedCategoryId = null;
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              CheckboxListTile(
                title: const Text('Sans catégorie'),
                value: selectedCategories.contains(null),
                onChanged: (v) {
                  setState(() {
                    selectedCategories.remove('__ALL__');
                    if (v == true) {
                      selectedCategories.add(null);
                    } else {
                      selectedCategories.remove(null);
                    }
                    focusedCategoryId = null;
                    if (selectedCategories.isEmpty) {
                      selectedCategories.add('__ALL__');
                    }
                  });
                },
              ),
              const Divider(),
              ...cats.map((c) {
                final selected = selectedCategories.contains(c.id);
                return CheckboxListTile(
                  title: Text(c.name),
                  value: selected,
                  secondary: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(c.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      selectedCategories.remove('__ALL__');
                      if (v == true) {
                        selectedCategories.add(c.id);
                      } else {
                        selectedCategories.remove(c.id);
                      }
                      focusedCategoryId = null;
                      if (selectedCategories.isEmpty) {
                        selectedCategories.add('__ALL__');
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────
  IconButton _toggleIcon({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: onTap,
    );
  }

  Widget _miniFilterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
