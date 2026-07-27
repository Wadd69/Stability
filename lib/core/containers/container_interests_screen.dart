import 'package:flutter/material.dart';

import 'container_model.dart';
import 'interest_adjustment.dart';
import 'interest_adjustments_store.dart';

import '../finance/transaction_type.dart';
import '../finance/transactions_store.dart';
import '../finance/active_month_store.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

/// Ligne calculée d’intérêt (lecture + correction possible)
class InterestLine {
  final DateTime quinzaineDate;
  final double capital;
  final double computedInterest;
  final double displayedInterest;
  final bool isCorrected;

  InterestLine({
    required this.quinzaineDate,
    required this.capital,
    required this.computedInterest,
    required this.displayedInterest,
    required this.isCorrected,
  });
}

class ContainerInterestsScreen extends StatelessWidget {
  final ContainerModel container;

  const ContainerInterestsScreen({
    super.key,
    required this.container,
  });

  List<Widget> _helpAction(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.help_outline),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const HelpScreen(topic: HelpTopic.savingsInterests),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (container.interestRates.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Intérêts – ${container.name}'),
          actions: _helpAction(context),
        ),
        body: const Center(
          child: Text('Aucun taux d’intérêt défini pour ce conteneur'),
        ),
      );
    }

    final lines = _computeInterests(container);

    return Scaffold(
      appBar: AppBar(
        title: Text('Intérêts – ${container.name}'),
        actions: _helpAction(context),
      ),
      body: lines.isEmpty
          ? const Center(child: Text('Aucun intérêt calculable'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final l = lines[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            _formatQuinzaine(l.quinzaineDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capital pris en compte : ${l.capital.toStringAsFixed(2)} €',
                              ),
                              if (l.isCorrected)
                                Text(
                                  'Calculé : +${l.computedInterest.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+${l.displayedInterest.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  color: l.isCorrected
                                      ? context.appColors.warning
                                      : context.appColors.positive,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Corriger l’intérêt',
                                onPressed: () {
                                  _editInterest(context, container, l);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter les intérêts au solde'),
                      onPressed: () {
                        for (final l in lines) {
                          TransactionsStore.addInterestTransaction(
                            containerId: container.id,
                            quinzaineDate: l.quinzaineDate,
                            amount: l.displayedInterest,
                            containerName: container.name,
                          );
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Intérêts ajoutés au solde'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────
  // CALCUL DES INTÉRÊTS — LOGIQUE BANCAIRE RÉELLE
  // ─────────────────────────────────────────────

  List<InterestLine> _computeInterests(ContainerModel container) {
    final txs = TransactionsStore.historyByContainer(container.id)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (txs.isEmpty) return [];

    final quinzaines = _buildQuinzaineTimeline(
      txs.first.date,
      _activeMonthEnd(),
    );

    double capital = 0;
    int txIndex = 0;
    final List<InterestLine> result = [];

    for (final q in quinzaines) {
      while (txIndex < txs.length &&
          _txEligibleForQuinzaine(txs[txIndex].date, q)) {
        final t = txs[txIndex];
        capital += t.type == TransactionType.income
            ? t.amount
            : -t.amount;
        txIndex++;
      }

      if (capital <= 0) continue;

      final ratePeriod = container.rateAt(q);
      if (ratePeriod == null) continue;

      final computed =
          capital * (ratePeriod.rate / 100) / 24;

      final adjustment =
          InterestAdjustmentsStore.getFor(container.id, q);

      result.add(
        InterestLine(
          quinzaineDate: q,
          capital: capital,
          computedInterest: computed,
          displayedInterest:
              adjustment?.correctedInterest ?? computed,
          isCorrected: adjustment != null,
        ),
      );
    }

    return result;
  }

  // ─────────────────────────────────────────────
  // RÈGLE BANCAIRE DES QUINZAINES (FIX DÉFINITIF)
  // ─────────────────────────────────────────────

  bool _txEligibleForQuinzaine(DateTime tx, DateTime q) {
    // 1ère quinzaine : opérations ≤ 15 du mois précédent inclus
    if (q.day == 1) {
      return !tx.isAfter(
        DateTime(q.year, q.month, 15),
      );
    }

    // 2e quinzaine : opérations ≤ fin du mois inclus
    return !tx.isAfter(
      DateTime(q.year, q.month + 1, 0),
    );
  }

  /// Dernier jour du mois actif de l'app (pas "aujourd'hui" en vrai) :
  /// les intérêts doivent suivre le calendrier simulé par l'utilisateur
  /// (clôtures de mois), pas l'horloge réelle de l'appareil.
  DateTime _activeMonthEnd() {
    final parts = ActiveMonthStore.current.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateTime(year, month + 1, 0);
  }

  List<DateTime> _buildQuinzaineTimeline(DateTime start, DateTime end) {
    final List<DateTime> dates = [];
    DateTime cursor = DateTime(start.year, start.month, 1);

    while (!cursor.isAfter(end)) {
      dates.add(DateTime(cursor.year, cursor.month, 1));
      dates.add(DateTime(cursor.year, cursor.month, 16));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return dates;
  }

  // ─────────────────────────────────────────────
  // UI / DIALOG
  // ─────────────────────────────────────────────

  void _editInterest(
    BuildContext context,
    ContainerModel container,
    InterestLine line,
  ) {
    final controller = TextEditingController(
      text: line.displayedInterest.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_formatQuinzaine(line.quinzaineDate)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Intérêt à valider (€)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (value == null) return;

              InterestAdjustmentsStore.addOrUpdate(
                InterestAdjustment(
                  containerId: container.id,
                  quinzaineDate: line.quinzaineDate,
                  computedInterest: line.computedInterest,
                  correctedInterest: value,
                ),
              );

              Navigator.pop(context);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  String _formatQuinzaine(DateTime d) {
    return d.day == 1
        ? 'Quinzaine du 01/${_mm(d)}/${d.year}'
        : 'Quinzaine du 16/${_mm(d)}/${d.year}';
  }

  String _mm(DateTime d) => d.month.toString().padLeft(2, '0');
}
