import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stability/core/finance/transaction_type.dart';

import '../../core/finance/transaction.dart';
import '../../theme/app_colors.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';

class CategoryChartsScreen extends StatefulWidget {
  final String title;
  final List<Transaction> transactions;

  const CategoryChartsScreen({
    super.key,
    required this.title,
    required this.transactions,
  });

  @override
  State<CategoryChartsScreen> createState() => _CategoryChartsScreenState();
}

class _CategoryChartsScreenState extends State<CategoryChartsScreen> {
  // Toggle % / €
  bool asPercentage = false;

  final String _currencySymbol = '€';

  // ─────────────────────────
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

  Widget _helpAction(BuildContext context) {
    return IconButton(
      tooltip: 'Aide',
      icon: const Icon(Icons.help_outline),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HelpScreen(topic: HelpTopic.archiveDetail),
          ),
        );
      },
    );
  }

  // ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final expenses = widget.transactions
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => a.amount.compareTo(b.amount));

    if (expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [_helpAction(context)],
        ),
        body: const Center(child: Text('Aucune dépense')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Text(
              asPercentage ? '%' : _currencySymbol,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            tooltip: asPercentage ? 'Afficher en montant' : 'Afficher en %',
            onPressed: () => setState(() => asPercentage = !asPercentage),
          ),
          _helpAction(context),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sunDonut(expenses),
          const SizedBox(height: 24),
          _transactionsAccordion(expenses),
        ],
      ),
    );
  }

  // ─────────────────────────
  // 🌞 SUN DONUT — TRANSACTIONS
  Widget _sunDonut(List<Transaction> tx) {
    final total = tx.fold<double>(0, (s, t) => s + t.amount);

    final minAmount = tx.first.amount;
    final maxAmount = tx.last.amount;

    return _card(
      'Répartition',
      SizedBox(
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                centerSpaceRadius: 70,
                sectionsSpace: 2,
                sections: tx.map((t) {
                  final ratio = t.amount / total;
                  final showLabel = ratio > 0.06;

                  return PieChartSectionData(
                    value: t.amount,
                    radius: 80,
                    color: _shadeFromAmount(
                      Colors.red,
                      t.amount,
                      minAmount,
                      maxAmount,
                    ),
                    title: showLabel
                        ? asPercentage
                            ? '${t.label}\n${(ratio * 100).toStringAsFixed(1)}%'
                            : '${t.label}\n${t.amount.toStringAsFixed(0)}$_currencySymbol'
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

            // ── Centre
            IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${total.toStringAsFixed(0)}$_currencySymbol',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      420,
    );
  }

  // ─────────────────────────
  // 📂 ACCORDÉON — TRANSACTIONS
  Widget _transactionsAccordion(List<Transaction> tx) {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Mouvements',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        children: tx.map(_transactionTile).toList(),
      ),
    );
  }

  ListTile _transactionTile(Transaction t) {
    return ListTile(
      title: Text(t.label),
      trailing: Text(
        '-${t.amount.toStringAsFixed(2)}$_currencySymbol',
        style: TextStyle(
          color: context.appColors.negative,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─────────────────────────
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
