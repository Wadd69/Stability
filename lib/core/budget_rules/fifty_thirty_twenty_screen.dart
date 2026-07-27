import 'package:flutter/material.dart';

import '../finance/categories_store.dart';
import '../finance/budget_bucket.dart';
import '../finance/transactions_store.dart';
import '../finance/transaction_type.dart';
import 'category_allocations_store.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

class FiftyThirtyTwentyScreen extends StatefulWidget {
  final String monthKey;
  final String monthLabel;

  const FiftyThirtyTwentyScreen({
    super.key,
    required this.monthKey,
    required this.monthLabel,
  });

  @override
  State<FiftyThirtyTwentyScreen> createState() =>
      _FiftyThirtyTwentyScreenState();
}

class _FiftyThirtyTwentyScreenState extends State<FiftyThirtyTwentyScreen> {
  Future<void> _editPlannedIncome() async {
    final controller = TextEditingController(
      text: CategoryAllocationsStore.getPlannedIncome(widget.monthKey)
          .toStringAsFixed(2),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revenu prévisionnel du mois'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Montant (€)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (value == null) return;
    await CategoryAllocationsStore.setPlannedIncome(widget.monthKey, value);
    if (!mounted) return;
    setState(() {});
  }

  Map<BudgetBucket?, double> _spentByBucket() {
    final spent = <BudgetBucket?, double>{};

    final expenses = TransactionsStore.transactionsForMonth(widget.monthKey)
        .where((t) => t.type == TransactionType.expense && t.transferId == null);

    for (final t in expenses) {
      final bucket =
          t.category != null ? CategoriesStore.getById(t.category!)?.bucket : null;
      spent[bucket] = (spent[bucket] ?? 0) + t.amount;
    }

    return spent;
  }

  @override
  Widget build(BuildContext context) {
    final income = CategoryAllocationsStore.getPlannedIncome(widget.monthKey);
    final spentByBucket = _spentByBucket();
    final unclassified = spentByBucket[null] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('50 / 30 / 20 — ${widget.monthLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.fiftyThirtyTwenty),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Revenu prévisionnel du mois'),
                  const SizedBox(height: 4),
                  Text(
                    '${income.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _editPlannedIncome,
                    child: const Text('Modifier'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (income == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Définissez le revenu prévisionnel pour voir les objectifs '
                'de chaque catégorie.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...BudgetBucket.values.map((bucket) {
              final target = income * bucket.targetShare;
              final spent = spentByBucket[bucket] ?? 0;
              final ratio = target == 0 ? 0.0 : (spent / target).clamp(0, 2);
              final over = spent > target;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio > 1 ? 1 : ratio.toDouble(),
                          minHeight: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          color: over
                              ? context.appColors.negative
                              : context.appColors.positive,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${spent.toStringAsFixed(2)} € dépensés sur '
                        '${target.toStringAsFixed(2)} € prévus',
                        style: TextStyle(
                          color: over ? context.appColors.negative : null,
                          fontWeight: over ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          if (unclassified > 0) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Dépenses non classées'),
                subtitle: const Text(
                  'Catégories sans besoin/envie/épargne assigné',
                ),
                trailing: Text(
                  '${unclassified.toStringAsFixed(2)} €',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
