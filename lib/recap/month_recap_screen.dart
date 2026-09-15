import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stability/core/finance/finance.dart';
import 'package:stability/core/finance/categories_store.dart';
import '../core/containers/containers_store.dart';
import '../core/finance/transaction_analysis.dart';
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

  /// Supports inclus dans l'analyse — `null` tant que non initialisé (voir
  /// [_ensureContainerSelectionInitialized]), pour ne se limiter au compte
  /// courant qu'une fois la liste des supports actifs connue.
  Set<String>? _selectedContainerIds;

  void _ensureContainerSelectionInitialized(ContainersStore containersStore) {
    if (_selectedContainerIds != null) return;
    final primary = containersStore.primaryCurrentAccount;
    // Par défaut, limité au compte courant — sauf si aucun compte courant
    // n'est défini, auquel cas on retombe sur tous les supports actifs
    // pour ne jamais afficher une analyse vide sans raison claire.
    _selectedContainerIds = primary != null
        ? {primary.id}
        : containersStore.active.map((c) => c.id).toSet();
  }

  // ─────────────────────────
  // 🔒 SOURCE UNIQUE D’ANALYSE
  // Exclut STRICTEMENT les carryOver, et les virements neutres (voir
  // TransactionAnalysis — un virement n'est ni une vraie dépense ni une
  // vraie rentrée, sauf remboursement de crédit). Limité par défaut au
  // compte courant, mais l'utilisateur peut inclure d'autres supports
  // (voir _accountSelector).
  List<Transaction> get _analysisTransactions {
    final containersStore = context.read<ContainersStore>();
    _ensureContainerSelectionInitialized(containersStore);
    final containerIds = _selectedContainerIds!;

    final scoped = widget.transactions
        .where((t) => containerIds.contains(t.containerId))
        .toList();

    return TransactionAnalysis.filterForAnalysis(
      scoped.where((t) => !t.isCarryOver).toList(),
      containersStore,
    );
  }

  Widget _accountSelector(ContainersStore containersStore) {
    final containers = containersStore.active;
    if (containers.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comptes inclus dans l\'analyse',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: containers.map((c) {
              final selected = _selectedContainerIds!.contains(c.id);
              return FilterChip(
                label: Text(c.name),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedContainerIds!.add(c.id);
                    } else {
                      _selectedContainerIds!.remove(c.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

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
    final containersStore = context.watch<ContainersStore>();
    _ensureContainerSelectionInitialized(containersStore);

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
          _accountSelector(containersStore),
          if (showPie) ...[
            PieChartModeSelector(
              value: pieMode,
              onChanged: (m) => setState(() => pieMode = m),
            ),
            const SizedBox(height: 12),
            CategoryPieChart(
              transactions: _analysisTransactions
                  .where((t) => _allowed(t.category))
                  .toList(),
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
          color: isIncome
              ? context.appColors.positive
              : context.appColors.negative,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _allowed(String? id) =>
      selectedCategories.contains('__ALL__') || selectedCategories.contains(id);

  String _categoryName(String? id) => id == null
      ? 'Sans catégorie'
      : CategoriesStore.getById(id)?.name ?? 'Catégorie supprimée';
}
