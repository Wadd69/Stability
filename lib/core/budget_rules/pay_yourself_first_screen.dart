import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'budget_automation_service.dart';
import 'category_allocations_store.dart';
import '../../accounts/current_account.dart';
import '../../backend/cloud_accounts_repository.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';
import '../containers/container_model.dart';
import '../containers/containers_store.dart';

/// Écran du mode "Paie-toi en premier" : un seul pourcentage cible du
/// revenu prévisionnel, viré en priorité vers un support d'épargne dédié.
/// Le reste de l'argent n'est pas suivi poste par poste.
class PayYourselfFirstScreen extends StatefulWidget {
  final String monthKey;
  final String monthLabel;

  const PayYourselfFirstScreen({
    super.key,
    required this.monthKey,
    required this.monthLabel,
  });

  @override
  State<PayYourselfFirstScreen> createState() => _PayYourselfFirstScreenState();
}

class _PayYourselfFirstScreenState extends State<PayYourselfFirstScreen> {
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

  Future<void> _editSettings(ContainersStore containersStore) async {
    final percentController = TextEditingController(
      text: CurrentAccount.active.payYourselfFirstPercent != null
          ? (CurrentAccount.active.payYourselfFirstPercent! * 100)
              .toStringAsFixed(0)
          : '',
    );
    String? destinationId = CurrentAccount.active.payYourselfFirstContainerId;
    final containers = containersStore.active;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Réglages de l\'épargne'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: percentController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: const InputDecoration(
                  labelText: 'Pourcentage cible (%)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: destinationId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Support d\'épargne destination',
                ),
                items: containers
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setModalState(() => destinationId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final percent = double.tryParse(percentController.text);
                final updated = CurrentAccount.active.copyWith(
                  payYourselfFirstPercent:
                      percent != null ? percent / 100 : null,
                  payYourselfFirstContainerId: destinationId,
                );
                await CloudAccountsRepository.updateAccount(updated);
                CurrentAccount.active = updated;
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _launch(ContainersStore containersStore) async {
    final primary = containersStore.primaryCurrentAccount;
    if (primary == null) return;

    final amount =
        BudgetAutomationService.payYourselfFirstAmount(widget.monthKey);
    if (amount <= 0) return;

    await BudgetAutomationService.launchPayYourselfFirst(
      monthKey: widget.monthKey,
      sourceContainerId: primary.id,
      amount: amount,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${amount.toStringAsFixed(2)} € viré.')),
    );
  }

  Future<void> _validate(ContainersStore containersStore) async {
    final count = await BudgetAutomationService.validateTransfers(
      widget.monthKey,
      containersStore,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Rien à valider.'
              : '$count virement${count > 1 ? 's' : ''} validé'
                  '${count > 1 ? 's' : ''}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containersStore = context.watch<ContainersStore>();
    final income = CategoryAllocationsStore.getPlannedIncome(widget.monthKey);
    final percent = CurrentAccount.active.payYourselfFirstPercent;
    final destinationId = CurrentAccount.active.payYourselfFirstContainerId;
    ContainerModel? destination;
    if (destinationId != null) {
      for (final c in containersStore.all) {
        if (c.id == destinationId) {
          destination = c;
          break;
        }
      }
    }
    final amount =
        BudgetAutomationService.payYourselfFirstAmount(widget.monthKey);
    final launched =
        BudgetAutomationService.isPayYourselfFirstLaunched(widget.monthKey);

    return Scaffold(
      appBar: AppBar(
        title: Text('Paie-toi en premier — ${widget.monthLabel}'),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.tune),
            onPressed: () => _editSettings(containersStore),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.payYourselfFirst),
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
                        fontSize: 22, fontWeight: FontWeight.bold),
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
          if (percent == null || destination == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Réglez le pourcentage cible et le support d\'épargne '
                '(icône ⚙️ en haut) pour activer le versement automatique.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}% vers '
                      '${destination.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${amount.toStringAsFixed(2)} € à épargner ce mois-ci',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.appColors.positive,
                      ),
                    ),
                    if (launched) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Déjà lancé ce mois-ci.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: launched || amount <= 0
                    ? null
                    : () => _launch(containersStore),
                child: const Text('Lancer le versement du mois'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: launched ? () => _validate(containersStore) : null,
                child: const Text('Valider le versement'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Le reste de votre argent n\'est pas suivi poste par poste — '
            'vous le gérez librement, comme en mode "Suivi libre". Vous '
            'pouvez tout de même définir un budget mensuel facultatif par '
            'catégorie depuis l\'écran Catégories.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
