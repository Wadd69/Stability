import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/archives/archived_month.dart';
import '../core/containers/containers_store.dart';
import '../core/finance/categories_store.dart';
import '../core/finance/transaction_analysis.dart';
import 'package:stability/core/finance/finance.dart';
import '../theme/app_colors.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../shared/category_pie_chart.dart';

class MonthArchiveScreen extends StatefulWidget {
  final ArchivedMonth month;

  const MonthArchiveScreen({
    super.key,
    required this.month,
  });

  @override
  State<MonthArchiveScreen> createState() => _MonthArchiveScreenState();
}

class _MonthArchiveScreenState extends State<MonthArchiveScreen> {
  bool asPercentage = false;
  PieChartMode pieMode = PieChartMode.expenses;

  // ─────────────────────────
  // COULEURS (encore utilisée par l'accordéon ci-dessous)
  Color _baseCategoryColor(String? id) {
    if (id == null) return Colors.grey;
    final c = CategoriesStore.getById(id);
    return c == null ? Colors.grey : Color(c.colorValue);
  }

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final tx = TransactionAnalysis.filterForAnalysis(
      TransactionsStore.archivedForMonth(widget.month.id),
      context.read<ContainersStore>(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Analyse – ${widget.month.label}'),
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
          PieChartModeSelector(
            value: pieMode,
            onChanged: (m) => setState(() => pieMode = m),
          ),
          const SizedBox(height: 12),
          CategoryPieChart(
            transactions: tx,
            mode: pieMode,
            asPercentage: asPercentage,
          ),
          const SizedBox(height: 24),
          _categoriesAccordion(tx),
        ],
      ),
    );
  }

  // ─────────────────────────
  // ACCORDÉON (IDENTIQUE UX MONTH RECAP)
  Widget _categoriesAccordion(List<Transaction> tx) {
    final Map<String?, List<Transaction>> grouped = {};

    for (final t in tx) {
      grouped.putIfAbsent(t.category, () => []).add(t);
    }

    return Column(
      children: grouped.entries.map((e) {
        final color = _baseCategoryColor(e.key);
        final txList = List<Transaction>.from(e.value)
          ..sort((a, b) => b.date.compareTo(a.date));

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
            children: txList.map(_transactionTile).toList(),
          ),
        );
      }).toList(),
    );
  }

  ListTile _transactionTile(Transaction t) {
    final isIncome = t.type == TransactionType.income;

    return ListTile(
      title: Text(t.label),
      subtitle: Text(
        '${t.date.day.toString().padLeft(2, '0')}/'
        '${t.date.month.toString().padLeft(2, '0')}/'
        '${t.date.year}',
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)}€',
        style: TextStyle(
          color: isIncome
              ? context.appColors.positive
              : context.appColors.negative,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _categoryName(String? id) {
    if (id == null) return 'Sans catégorie';
    return CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';
  }
}
