import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'container_model.dart';
import 'capitalization_engine.dart';
import 'containers_store.dart';
import '../finance/add_transaction_sheet.dart';
import '../finance/transaction_type.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

class ContainerRetirementScreen extends StatefulWidget {
  final ContainerModel container;

  const ContainerRetirementScreen({
    super.key,
    required this.container,
  });

  @override
  State<ContainerRetirementScreen> createState() =>
      _ContainerRetirementScreenState();
}

class _ContainerRetirementScreenState
    extends State<ContainerRetirementScreen> {
  DateTime? _openedAt;
  double? _annualRate;
  InsuranceInterestMode? _mode;
  double? _correctedValue;
  DateTime? _unlockDate;

  late DateTime _calculationDate;

  @override
  void initState() {
    super.initState();

    _openedAt = widget.container.insuranceOpenedAt;
    _annualRate = widget.container.insuranceAnnualRate;
    _mode = widget.container.insuranceInterestMode;
    _correctedValue = widget.container.insuranceCorrectedValue;
    _unlockDate = widget.container.retirementUnlockDate;

    final now = DateTime.now();
    _calculationDate = DateTime(now.year, 12, 31);
  }

  bool get _isLocked =>
      _unlockDate != null && DateTime.now().isBefore(_unlockDate!);

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
        title: Text('Retraite (PER) – ${container.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.retirement),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_unlockDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (_isLocked
                        ? context.appColors.warning
                        : context.appColors.positive)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isLocked ? Icons.lock_outline : Icons.lock_open,
                    color: _isLocked
                        ? context.appColors.warning
                        : context.appColors.positive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLocked
                          ? 'Épargne indisponible jusqu\'au '
                              '${_formatDate(_unlockDate!)} (sauf déblocage '
                              'anticipé légal : achat résidence principale, '
                              'invalidité, décès du conjoint, expiration '
                              'des droits au chômage, surendettement, '
                              'cessation d\'activité non salariée).'
                          : 'Épargne disponible depuis le '
                              '${_formatDate(_unlockDate!)}.',
                    ),
                  ),
                ],
              ),
            ),

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

          _sectionTitle('Plan'),

          _dateTile(
            label: 'Date d\'ouverture',
            value: _openedAt,
            onChanged: (d) => setState(() => _openedAt = d),
          ),

          _numberTile(
            label: 'Taux annuel (%)',
            value: _annualRate,
            onChanged: (v) => setState(() => _annualRate = v),
          ),

          _modeTile(),

          _dateTile(
            label: 'Date de déblocage (retraite)',
            value: _unlockDate,
            onChanged: (d) => setState(() => _unlockDate = d),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Simulation'),

          _dateTile(
            label: 'Date de calcul',
            value: _calculationDate,
            onChanged: (d) =>
                setState(() => _calculationDate = d ?? _calculationDate),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.appColors.warning,
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

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

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
      trailing: Text(value == null ? '—' : _formatDate(value)),
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
        final selected = await showDialog<InsuranceInterestMode>(
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  Future<void> _save() async {
    final updated = widget.container.copyWith(
      insuranceOpenedAt: _openedAt,
      insuranceAnnualRate: _annualRate,
      insuranceInterestMode: _mode,
      insuranceCorrectedValue: _correctedValue,
      insuranceCalculatedValue: null,
      retirementUnlockDate: _unlockDate,
    );

    await context.read<ContainersStore>().updateContainer(updated);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
