import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/containers/containers_store.dart';
import '../core/finance/forecast_service.dart';
import '../core/finance/recurring_overrides_store.dart';
import '../theme/app_colors.dart';

const _kMonthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  final month = int.parse(parts[1]);
  return '${_kMonthNames[month - 1]} ${parts[0]}';
}

String _dayLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Écran de prévision du mois suivant, à partir des transactions
/// récurrentes actives (voir [ForecastService]). Ne crée et ne clôture
/// jamais rien de son propre chef — la seule écriture possible est une
/// surcharge de montant ponctuelle (ex: salaire variable), consommée par
/// `RecurringTransactionsStore.generateDueForMonth` le moment venu.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(ForecastItem item) {
    final key = '${item.recurringId}_${item.overrideMonthKey}';
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: item.signedAmount.abs().toStringAsFixed(2),
      ),
    );
  }

  /// Couleur d'un solde selon son propre signe (rouge si négatif, vert si
  /// positif, couleur de texte par défaut si exactement 0) — pas une
  /// comparaison relative à un autre solde.
  Color _balanceColor(BuildContext context, double amount) {
    if (amount > 0.005) return context.appColors.positive;
    if (amount < -0.005) return context.appColors.negative;
    return Theme.of(context).colorScheme.onSurface;
  }

  Future<void> _saveOverride(ForecastItem item, String text) async {
    final amount = double.tryParse(text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    await RecurringOverridesStore.setOverride(
      item.recurringId!,
      item.overrideMonthKey!,
      amount,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final containersStore = context.watch<ContainersStore>();
    final forecast = ForecastService.compute(containersStore);

    return Scaffold(
      appBar: AppBar(
        title: Text('Prévision — ${_monthLabel(forecast.monthKey)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Basé sur vos transactions récurrentes actives et le solde '
            'actuel de vos supports — rien n\'est créé ni clôturé ici. Les '
            'montants avec un crayon sont modifiables (ex: salaire '
            'variable) : la correction s\'applique à la vraie transaction '
            'quand elle sera générée.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Soldes projetés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (forecast.containers.isEmpty)
                    const Text('Aucun support actif.')
                  else
                    for (final c in forecast.containers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(c.container.name)),
                            Text(
                              '${c.currentBalance.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward, size: 14),
                            ),
                            Text(
                              '${c.projectedBalance.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _balanceColor(
                                  context,
                                  c.projectedBalance,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Entrées prévues'),
                        Text(
                          '+${forecast.totalIncome.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.appColors.positive,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Sorties prévues'),
                        Text(
                          '-${forecast.totalExpense.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.appColors.negative,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mouvements prévus',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (forecast.items.isEmpty)
                    const Text('Aucune récurrence prévue pour ce mois-ci.')
                  else
                    for (final item in forecast.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                _dayLabel(item.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.editable)
                              SizedBox(
                                width: 130,
                                child: TextField(
                                  controller: _controllerFor(item),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: item.signedAmount >= 0
                                        ? context.appColors.positive
                                        : context.appColors.negative,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixIcon:
                                        const Icon(Icons.edit, size: 14),
                                    prefixText:
                                        item.signedAmount >= 0 ? '+' : '-',
                                    prefixStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: item.signedAmount >= 0
                                          ? context.appColors.positive
                                          : context.appColors.negative,
                                    ),
                                    suffixText: '€',
                                    border: const OutlineInputBorder(),
                                  ),
                                  onEditingComplete: () => _saveOverride(
                                    item,
                                    _controllerFor(item).text,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '${item.signedAmount >= 0 ? '+' : ''}'
                                '${item.signedAmount.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: item.signedAmount >= 0
                                      ? context.appColors.positive
                                      : context.appColors.negative,
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
