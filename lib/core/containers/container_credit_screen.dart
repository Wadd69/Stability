import 'package:flutter/material.dart';

import 'container_model.dart';
import 'container_type.dart';
import '../../containers/edit_container_sheet.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

/// Écran dédié d'un support "Crédit" (immo, conso, revolving). Modèle
/// volontairement simple : mensualité saisie à la main, capital restant dû
/// suivi manuellement — le nombre de mois restants est une estimation
/// dérivée (capital restant / mensualité), pas un échéancier stocké.
class ContainerCreditScreen extends StatefulWidget {
  final ContainerModel container;

  const ContainerCreditScreen({super.key, required this.container});

  @override
  State<ContainerCreditScreen> createState() => _ContainerCreditScreenState();
}

class _ContainerCreditScreenState extends State<ContainerCreditScreen> {
  late ContainerModel _container;

  @override
  void initState() {
    super.initState();
    _container = widget.container;
  }

  Future<void> _edit() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditContainerSheet(container: _container),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _container.creditRemainingBalance;
    final monthly = _container.creditMonthlyPayment;
    final original = _container.creditOriginalAmount;
    final rate = _container.creditAnnualRate;

    final monthsLeft = (remaining != null && monthly != null && monthly > 0)
        ? (remaining / monthly).ceil()
        : null;

    final progress = (original != null && original > 0 && remaining != null)
        ? (1 - (remaining / original)).clamp(0.0, 1.0)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_container.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.credit),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _container.creditKind?.label ?? 'Crédit',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            remaining == null
                ? 'Non configuré'
                : '-${remaining.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.appColors.negative,
            ),
          ),
          const Text('Capital restant dû'),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: context.appColors.positive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)} % remboursé',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Mensualité', monthly),
                  _row('Montant emprunté initial', original),
                  _row('Taux d\'intérêt annuel', rate, suffix: '%'),
                  _row(
                    'Temps restant estimé',
                    null,
                    text: monthsLeft == null
                        ? '—'
                        : monthsLeft < 12
                            ? '$monthsLeft mois'
                            : '${(monthsLeft / 12).floor()} an'
                                '${(monthsLeft / 12).floor() > 1 ? 's' : ''}'
                                ' et ${monthsLeft % 12} mois',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Le capital restant dû baisse automatiquement dès qu\'un '
            'virement (manuel ou récurrent) crédite ce support.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double? value,
      {String suffix = '€', String? text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            text ??
                (value == null ? '—' : '${value.toStringAsFixed(2)} $suffix'),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
