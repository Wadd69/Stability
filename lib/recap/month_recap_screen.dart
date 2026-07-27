import 'package:flutter/material.dart';
import 'package:stability/core/finance/finance.dart';
import 'package:stability/core/finance/categories_store.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../theme/app_colors.dart';
import '../shared/category_pie_chart.dart';

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
  PieChartMode pieMode = PieChartMode.expenses;

  final Set<String?> selectedCategories = {'__ALL__'};

  // ─────────────────────────
  // 🔒 SOURCE UNIQUE D’ANALYSE
  // Exclut STRICTEMENT les carryOver
  List<Transaction> get _analysisTransactions =>
      widget.transactions.where((t) => !t.isCarryOver).toList();

  // ─────────────────────────
  // COULEURS (encore utilisées par l'accordéon ci-dessous)
  Color _baseCategoryColor(String? id) {
    if (id == null) return Colors.grey;
    final c = CategoriesStore.getById(id);
    return c == null ? Colors.grey : Color(c.colorValue);
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
          if (showPie) ...[
            PieChartModeSelector(
              value: pieMode,
              onChanged: (m) => setState(() => pieMode = m),
            ),
            const SizedBox(height: 12),
            CategoryPieChart(
              transactions:
                  _analysisTransactions.where((t) => _allowed(t.category)).toList(),
              mode: pieMode,
              asPercentage: asPercentage,
            ),
          ],
          const SizedBox(height: 24),
          _categoriesAccordion(),
        ],
      ),
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
          color: isIncome ? context.appColors.positive : context.appColors.negative,
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
}
