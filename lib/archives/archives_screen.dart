import 'package:flutter/material.dart';

import '../core/archives/archives_store.dart';
import '../core/finance/categories_store.dart';
import 'package:stability/core/finance/finance.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';

import 'month_archive_screen.dart';
import 'charts/year_charts_screen.dart';
import 'charts/global_history_line_chart.dart';
import 'charts/category_charts_screen.dart';
import '../screens/comparison/comparison_selector_screen.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vue globale'),
            Tab(text: 'Par période'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Comparer',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComparisonSelectorScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Aide',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.archives),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalOverview(),
          _buildYearHistory(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🌍 VUE GLOBALE — LECTURE SEULE
  // ─────────────────────────────────────────────
  Widget _buildGlobalOverview() {
    final months = ArchivesStore.all;

    if (months.isEmpty) {
      return const Center(child: Text('Aucune archive disponible'));
    }

    double income = 0;
    double expense = 0;
    final Map<String?, double> byCategory = {};

    for (final m in months) {
      income += m.totalIncome;
      expense += m.totalExpense;

      for (final t in m.transactions) {
        if (t.type != TransactionType.expense) continue;
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }
    }

    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _totalsCard(
          title: 'Depuis le début',
          income: income,
          expense: expense,
        ),
        const SizedBox(height: 24),

        // 👉 ACCÈS ANALYSE GLOBALE
        _actionCard(
          icon: Icons.show_chart,
          title: 'Analyse globale',
          subtitle: 'Courbes et répartition complètes',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GlobalHistoryLineChartScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        const Text(
          'Dépenses par catégorie',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...categories.map((e) {
          final label = (e.key == null)
              ? 'Sans catégorie'
              : CategoriesStore.getById(e.key!)?.name ??
                  'Catégorie supprimée';

          final List<Transaction> tx = [];
          for (final m in months) {
            for (final t in m.transactions) {
              if (t.type != TransactionType.expense) continue;
              if (t.category == e.key) {
                tx.add(t);
              }
            }
          }

          return ListTile(
            title: Text(label),
            trailing: Text('${e.value.toStringAsFixed(2)} €'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryChartsScreen(
                    title: label,
                    transactions: tx,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 📅 HISTORIQUE PAR ANNÉE
  // ─────────────────────────────────────────────
  Widget _buildYearHistory() {
    final years = ArchivesStore.years;

    if (years.isEmpty) {
      return const Center(child: Text('Aucune archive disponible'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final months = ArchivesStore.byYear(year);

        return ExpansionTile(
          title: Text(
            year.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Analyse de l’année'),
              subtitle: const Text('Courbes & répartition'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => YearChartsScreen(
                      year: year,
                      months: months,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ...months.map((m) {
              return ListTile(
                title: Text(m.label),
                subtitle: Text(
                  'Revenus : ${m.totalIncome.toStringAsFixed(2)} €'
                  ' • Dépenses : ${m.totalExpense.toStringAsFixed(2)} €',
                ),
                trailing: Text(
                  '${m.balance.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.balance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MonthArchiveScreen(month: m),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  Widget _totalsCard({
    required String title,
    required double income,
    required double expense,
  }) {
    final balance = income - expense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Revenus : ${income.toStringAsFixed(2)} €'),
            Text('Dépenses : ${expense.toStringAsFixed(2)} €'),
            const Divider(),
            Text(
              'Solde : ${balance.toStringAsFixed(2)} €',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
