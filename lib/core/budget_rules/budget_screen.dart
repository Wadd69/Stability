import 'package:flutter/material.dart';

import '../finance/categories_store.dart';
import 'category_allocations_store.dart';
import 'category_goals_store.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

class BudgetScreen extends StatefulWidget {
  final String monthKey;
  final String monthLabel;

  const BudgetScreen({
    super.key,
    required this.monthKey,
    required this.monthLabel,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
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
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, parsed);
            },
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

  Future<void> _editAllocation(Category category) async {
    final controller = TextEditingController(
      text: CategoryAllocationsStore.getAllocated(
        widget.monthKey,
        category.id,
      ).toStringAsFixed(2),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Allouer à "${category.name}"'),
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
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, parsed);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (value == null) return;
    await CategoryAllocationsStore.setAllocated(
      widget.monthKey,
      category.id,
      value,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editGoal(Category category) async {
    final controller = TextEditingController(
      text: CategoryGoalsStore.getGoal(category.id)?.toStringAsFixed(2) ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Objectif d\'épargne — ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Montant cible (€)',
            helperText: 'Laisser vide pour supprimer l\'objectif',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final parsed = double.tryParse(result.replaceAll(',', '.'));
    await CategoryGoalsStore.setGoal(category.id, parsed);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoriesStore.all;
    final categoryIds = categories.map((c) => c.id).toList();
    final readyToAssign =
        CategoryAllocationsStore.readyToAssign(widget.monthKey, categoryIds);

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget — ${widget.monthLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.budget),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: readyToAssign < 0
                ? context.appColors.negative.withValues(alpha: 0.1)
                : readyToAssign == 0
                    ? context.appColors.positive.withValues(alpha: 0.1)
                    : context.appColors.warning.withValues(alpha: 0.1),
            child: Column(
              children: [
                const Text('Reste à allouer'),
                const SizedBox(height: 4),
                Text(
                  '${readyToAssign.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: readyToAssign < 0
                        ? context.appColors.negative
                        : readyToAssign == 0
                            ? context.appColors.positive
                            : context.appColors.warning,
                  ),
                ),
                TextButton(
                  onPressed: _editPlannedIncome,
                  child: const Text('Définir le revenu prévisionnel'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: categories.isEmpty
                ? const Center(
                    child: Text('Aucune catégorie. Créez-en une d\'abord.'),
                  )
                : ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final allocated = CategoryAllocationsStore.getAllocated(
                        widget.monthKey,
                        category.id,
                      );
                      final carryIn = CategoryAllocationsStore.getCarryIn(
                        widget.monthKey,
                        category.id,
                      );
                      final spent = CategoryAllocationsStore.spentForCategory(
                        widget.monthKey,
                        category.id,
                      );
                      final remaining = CategoryAllocationsStore.remaining(
                        widget.monthKey,
                        category.id,
                      );
                      final goal = CategoryGoalsStore.getGoal(category.id);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(category.colorValue),
                        ),
                        title: Text(category.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              carryIn == 0
                                  ? 'Alloué: ${allocated.toStringAsFixed(2)} € · Dépensé: ${spent.toStringAsFixed(2)} €'
                                  : 'Alloué: ${allocated.toStringAsFixed(2)} € (+ ${carryIn.toStringAsFixed(2)} € reporté) · Dépensé: ${spent.toStringAsFixed(2)} €',
                            ),
                            if (goal != null) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (remaining / goal).clamp(0, 1).toDouble(),
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Objectif : ${remaining.toStringAsFixed(2)} € / '
                                '${goal.toStringAsFixed(2)} €',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${remaining.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: remaining < 0
                                    ? context.appColors.negative
                                    : context.appColors.positive,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                goal != null ? Icons.flag : Icons.flag_outlined,
                                size: 20,
                                color: goal != null
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              tooltip: 'Objectif d\'épargne',
                              onPressed: () => _editGoal(category),
                            ),
                          ],
                        ),
                        onTap: () => _editAllocation(category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
