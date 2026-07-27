import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../accounts/current_account.dart';
import '../../accounts/management_mode.dart';
import '../containers/containers_store.dart';
import '../finance/categories_store.dart';
import 'budget_automation_service.dart';

class _ReviewRow {
  final Category category;
  final String targetContainerId;
  final TextEditingController amountController;
  bool included;

  _ReviewRow({
    required this.category,
    required this.targetContainerId,
    required double amount,
  })  : amountController = TextEditingController(text: amount.toStringAsFixed(2)),
        included = amount > 0;

  double get amount =>
      double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;

  void dispose() => amountController.dispose();
}

/// Écran de revue avant de lancer les virements automatiques du mois :
/// une ligne par catégorie éligible (support de destination configuré +
/// montant calculé selon le mode de gestion actif), modifiable et
/// désactivable individuellement avant confirmation.
class LaunchMonthBudgetScreen extends StatefulWidget {
  final String monthKey;
  final String monthLabel;

  const LaunchMonthBudgetScreen({
    super.key,
    required this.monthKey,
    required this.monthLabel,
  });

  @override
  State<LaunchMonthBudgetScreen> createState() =>
      _LaunchMonthBudgetScreenState();
}

class _LaunchMonthBudgetScreenState extends State<LaunchMonthBudgetScreen> {
  final List<_ReviewRow> _rows = [];
  bool _loaded = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _load(ContainersStore containersStore) {
    if (_loaded) return;
    _loaded = true;

    final eligible =
        BudgetAutomationService.eligibleCategories(widget.monthKey, containersStore);
    final groups = BudgetAutomationService.groupByDestination(eligible);

    for (final group in groups) {
      if (BudgetAutomationService.isAlreadyLaunched(
          widget.monthKey, group.targetContainerId)) {
        continue;
      }
      for (final ec in group.categories) {
        _rows.add(
          _ReviewRow(
            category: ec.category,
            targetContainerId: group.targetContainerId,
            amount: ec.amount,
          ),
        );
      }
    }
  }

  Future<void> _confirm(ContainersStore containersStore) async {
    final primary = containersStore.primaryCurrentAccount;
    if (primary == null) return;

    final byDestination = <String, List<_ReviewRow>>{};
    for (final r in _rows) {
      if (!r.included || r.amount <= 0) continue;
      byDestination.putIfAbsent(r.targetContainerId, () => []).add(r);
    }

    final groups = byDestination.entries
        .map(
          (e) => DestinationGroup(
            targetContainerId: e.key,
            categories: e.value
                .map((r) => EligibleCategory(category: r.category, amount: r.amount))
                .toList(),
          ),
        )
        .toList();

    final count = groups.length;

    await BudgetAutomationService.launchMonth(
      monthKey: widget.monthKey,
      sourceContainerId: primary.id,
      groups: groups,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Rien à virer ce mois-ci.'
              : '$count virement${count > 1 ? 's' : ''} créé${count > 1 ? 's' : ''}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containersStore = context.watch<ContainersStore>();
    _load(containersStore);

    final primary = containersStore.primaryCurrentAccount;
    final byDestination = <String, List<_ReviewRow>>{};
    for (final r in _rows) {
      byDestination.putIfAbsent(r.targetContainerId, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lancer le budget — ${widget.monthLabel}'),
      ),
      body: primary == null
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Commencez par créer votre compte courant principal '
                '(support → compte courant, "Compte courant principal").',
              ),
            )
          : _rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    CurrentAccount.active.managementMode == ManagementMode.custom
                        ? 'Le mode personnalisé n\'est pas encore disponible : '
                            'aucune automatisation possible pour l\'instant.'
                        : 'Rien à virer ce mois-ci. Configurez un support de '
                            'destination sur vos catégories (dans "Gérer les '
                            'catégories") pour activer l\'automatisation.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Source : ${primary.name}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...byDestination.entries.map((entry) {
                      final targetName = containersStore.all
                          .firstWhere((c) => c.id == entry.key)
                          .name;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.arrow_forward, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    targetName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              ...entry.value.map(
                                (r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: r.included,
                                        onChanged: (v) =>
                                            setState(() => r.included = v ?? false),
                                      ),
                                      Expanded(child: Text(r.category.name)),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: r.amountController,
                                          enabled: r.included,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textAlign: TextAlign.right,
                                          decoration: const InputDecoration(
                                            suffixText: '€',
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
      bottomNavigationBar: (primary == null || _rows.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _confirm(containersStore),
                  child: const Text('Valider'),
                ),
              ),
            ),
    );
  }
}
