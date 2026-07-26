import 'package:flutter/material.dart';

import 'categories_store.dart';
import 'recurring_transaction.dart';
import 'recurring_transactions_store.dart';
import 'transaction_type.dart';
import 'edit_recurring_transaction_sheet.dart';
import 'active_month_store.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  Future<void> _openEditor({RecurringTransaction? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditRecurringTransactionSheet(existing: existing),
    );

    // Si le gabarit vient de devenir dû pour le mois actif, on le génère
    // tout de suite plutôt que d'attendre la prochaine clôture de mois.
    RecurringTransactionsStore.generateDueForMonth(ActiveMonthStore.current);
    setState(() {});
  }

  void _delete(RecurringTransaction r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la récurrence'),
        content: Text(
          '"${r.label}" ne sera plus générée automatiquement.\n\n'
          'Les transactions déjà créées restent inchangées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              RecurringTransactionsStore.remove(r.id);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = RecurringTransactionsStore.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions récurrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.recurringTransactions),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune transaction récurrente.\n\n'
                  'Ajoutez-en une pour que loyer, salaire ou abonnements '
                  'se créent automatiquement chaque mois.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = items[index];
                final isIncome = r.type == TransactionType.income;
                final categoryName =
                    r.category != null ? CategoriesStore.getById(r.category!)?.name : null;

                return ListTile(
                  leading: Icon(
                    isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                  title: Text(r.label),
                  subtitle: Text(
                    [
                      r.frequency.label,
                      if (categoryName != null) categoryName,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}${r.amount.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: r.active,
                        onChanged: (v) {
                          RecurringTransactionsStore.setActive(r.id, v);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(r),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(existing: r),
                );
              },
            ),
    );
  }
}
