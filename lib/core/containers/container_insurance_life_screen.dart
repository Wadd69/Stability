import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'container_model.dart';
import 'capitalization_engine.dart';
import 'containers_store.dart';
import '../finance/add_transaction_sheet.dart';
import '../finance/transaction_type.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';

class ContainerInsuranceLifeScreen extends StatefulWidget {
  final ContainerModel container;

  const ContainerInsuranceLifeScreen({
    super.key,
    required this.container,
  });

  @override
  State<ContainerInsuranceLifeScreen> createState() =>
      _ContainerInsuranceLifeScreenState();
}

class _ContainerInsuranceLifeScreenState
    extends State<ContainerInsuranceLifeScreen> {
  DateTime? _openedAt;
  double? _annualRate;
  InsuranceInterestMode? _mode;
  double? _correctedValue;

  /// ✅ DATE DE SIMULATION (CLÉ DU PROBLÈME)
  late DateTime _calculationDate;

  @override
  void initState() {
    super.initState();

    _openedAt = widget.container.insuranceOpenedAt;
    _annualRate = widget.container.insuranceAnnualRate;
    _mode = widget.container.insuranceInterestMode;
    _correctedValue = widget.container.insuranceCorrectedValue;

    // Par défaut : 31/12 de l’année en cours
    final now = DateTime.now();
    _calculationDate = DateTime(now.year, 12, 31);
  }

  @override
  Widget build(BuildContext context) {
    final container = widget.container;

    final calculatedValue =
        (_openedAt != null && _annualRate != null && _mode != null)
            ? CapitalizationEngine.computeValue(
                container: container.copyWith(
                  insuranceOpenedAt: _openedAt,
                  insuranceAnnualRate: _annualRate,
                  insuranceInterestMode: _mode,
                ),
                atDate: _calculationDate,
              )
            : null;

    final displayedValue = _correctedValue ?? calculatedValue;

    return Scaffold(
      appBar: AppBar(
        title: Text('Assurance-vie – ${container.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.insuranceLife),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Versement'),
                  onPressed: () => _openAddTransaction(TransactionType.income),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('Rachat'),
                  onPressed: () =>
                      _openAddTransaction(TransactionType.expense),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _sectionTitle('Contrat'),

          _dateTile(
            label: 'Date d’ouverture',
            value: _openedAt,
            onChanged: (d) => setState(() => _openedAt = d),
          ),

          _numberTile(
            label: 'Taux annuel (%)',
            value: _annualRate,
            onChanged: (v) => setState(() => _annualRate = v),
          ),

          _modeTile(),

          const SizedBox(height: 24),
          _sectionTitle('Simulation'),

          _dateTile(
            label: 'Date de calcul',
            value: _calculationDate,
            onChanged: (d) => setState(() => _calculationDate = d ?? _calculationDate),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Valeur'),

          ListTile(
            title: const Text('Valeur calculée'),
            trailing: Text(
              calculatedValue == null
                  ? '—'
                  : '${calculatedValue.toStringAsFixed(2)} €',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          ListTile(
            title: const Text('Valeur corrigée'),
            subtitle: const Text(
              'Écrase le calcul automatique',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Text(
              _correctedValue == null
                  ? '—'
                  : '${_correctedValue!.toStringAsFixed(2)} €',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            onTap: _editCorrectedValue,
          ),

          const Divider(),

          ListTile(
            title: const Text('Valeur retenue'),
            trailing: Text(
              displayedValue == null
                  ? '—'
                  : '${displayedValue.toStringAsFixed(2)} €',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value == null
            ? '—'
            : '${value.day.toString().padLeft(2, '0')}/'
              '${value.month.toString().padLeft(2, '0')}/'
              '${value.year}',
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }

  Widget _numberTile({
    required String label,
    required double? value,
    required ValueChanged<double?> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      trailing: Text(value == null ? '—' : value.toStringAsFixed(2)),
      onTap: () async {
        final controller = TextEditingController(
          text: value?.toStringAsFixed(2) ?? '',
        );

        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Valider'),
              ),
            ],
          ),
        );

        if (ok == true) {
          onChanged(
            double.tryParse(controller.text.replaceAll(',', '.')),
          );
        }
      },
    );
  }

  Widget _modeTile() {
    return ListTile(
      title: const Text('Mode de calcul'),
      trailing: Text(
        _mode == null
            ? '—'
            : _mode == InsuranceInterestMode.prorataTemporis
                ? 'Prorata temporis'
                : 'Intérêt plein',
      ),
      onTap: () async {
        final selected =
            await showDialog<InsuranceInterestMode>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Mode de calcul'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  InsuranceInterestMode.prorataTemporis,
                ),
                child: const Text('Prorata temporis'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  InsuranceInterestMode.fullYear,
                ),
                child: const Text('Intérêt plein'),
              ),
            ],
          ),
        );

        if (selected != null) {
          setState(() => _mode = selected);
        }
      },
    );
  }

  void _editCorrectedValue() async {
    final controller = TextEditingController(
      text: _correctedValue?.toStringAsFixed(2) ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Corriger la valeur'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _correctedValue = double.tryParse(
          controller.text.replaceAll(',', '.'),
        );
      });
    }
  }

  Future<void> _openAddTransaction(TransactionType type) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        type: type,
        initialContainerId: widget.container.id,
      ),
    );
    setState(() {});
  }

  void _save() {
    final updated = widget.container.copyWith(
      insuranceOpenedAt: _openedAt,
      insuranceAnnualRate: _annualRate,
      insuranceInterestMode: _mode,
      insuranceCorrectedValue: _correctedValue,
      insuranceCalculatedValue: null,
    );

    context.read<ContainersStore>().updateContainer(updated);
    Navigator.pop(context);
  }
}
