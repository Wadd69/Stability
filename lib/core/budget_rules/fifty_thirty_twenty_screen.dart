import 'package:flutter/material.dart';

import '../finance/categories_store.dart';
import '../finance/budget_bucket.dart';
import '../finance/transactions_store.dart';
import '../finance/transaction_type.dart';
import 'category_allocations_store.dart';
import '../../accounts/current_account.dart';
import '../../backend/cloud_accounts_repository.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

class _BucketRow {
  final TextEditingController nameController;
  final TextEditingController shareController;

  _BucketRow({required String name, required String share})
      : nameController = TextEditingController(text: name),
        shareController = TextEditingController(text: share);

  void dispose() {
    nameController.dispose();
    shareController.dispose();
  }
}

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

  /// Ouvre l'éditeur des enveloppes (nom + % au choix) : ajouter, retirer,
  /// renommer, ajuster. Enregistré sur le compte cloud actif.
  Future<void> _editBuckets() async {
    final rows = CurrentAccount.active.effectiveBuckets
        .map((b) => _BucketRow(
              name: b.name,
              share: (b.targetShare * 100).toStringAsFixed(0),
            ))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = rows.fold<double>(
            0,
            (sum, r) => sum + (double.tryParse(r.shareController.text) ?? 0),
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Enveloppes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ajouter une enveloppe',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          rows.add(_BucketRow(name: '', share: '0'));
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total actuel : ${total.toStringAsFixed(0)}%'
                    '${total != 100 ? ' (idéalement 100%)' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: total == 100
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : context.appColors.warning,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: row.nameController,
                              decoration:
                                  const InputDecoration(labelText: 'Nom'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: row.shareController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration:
                                  const InputDecoration(suffixText: '%'),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: rows.length <= 1
                                ? null
                                : () {
                                    rows.remove(row);
                                    setModalState(() {});
                                  },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newBuckets = <CustomBucket>[];
                        for (int i = 0; i < rows.length; i++) {
                          final name = rows[i].nameController.text.trim();
                          if (name.isEmpty) continue;
                          final share = (double.tryParse(
                                    rows[i].shareController.text,
                                  ) ??
                                  0) /
                              100;
                          newBuckets.add(CustomBucket(
                            id: 'bucket_$i',
                            name: name,
                            targetShare: share,
                          ));
                        }
                        final updated = CurrentAccount.active
                            .copyWith(customBuckets: newBuckets);
                        await CloudAccountsRepository.updateAccount(updated);
                        CurrentAccount.active = updated;
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final row in rows) {
      row.dispose();
    }
    if (!mounted) return;
    setState(() {});
  }

  Map<String?, double> _spentByBucket() {
    final spent = <String?, double>{};

    final expenses = TransactionsStore.transactionsForMonth(widget.monthKey)
        .where(
            (t) => t.type == TransactionType.expense && t.transferId == null);

    for (final t in expenses) {
      final bucketId = t.category != null
          ? CategoriesStore.getById(t.category!)?.bucketId
          : null;
      spent[bucketId] = (spent[bucketId] ?? 0) + t.amount;
    }

    return spent;
  }

  @override
  Widget build(BuildContext context) {
    final income = CategoryAllocationsStore.getPlannedIncome(widget.monthKey);
    final spentByBucket = _spentByBucket();
    final unclassified = spentByBucket[null] ?? 0;
    final buckets = CurrentAccount.active.effectiveBuckets;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pourcentages personnalisés — ${widget.monthLabel}'),
        actions: [
          IconButton(
            tooltip: 'Modifier les enveloppes',
            icon: const Icon(Icons.tune),
            onPressed: _editBuckets,
          ),
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
            ...buckets.map((bucket) {
              final target = income * bucket.targetShare;
              final spent = spentByBucket[bucket.id] ?? 0;
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
                        '${bucket.name} '
                        '(${(bucket.targetShare * 100).toStringAsFixed(0)}%)',
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
                  'Catégories sans enveloppe assignée',
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
