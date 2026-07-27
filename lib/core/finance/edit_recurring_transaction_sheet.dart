import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../containers/containers_store.dart';
import 'categories_store.dart';
import 'recurring_transaction.dart';
import 'recurring_transactions_store.dart';
import 'transaction_type.dart';

class EditRecurringTransactionSheet extends StatefulWidget {
  final RecurringTransaction? existing;

  const EditRecurringTransactionSheet({super.key, this.existing});

  @override
  State<EditRecurringTransactionSheet> createState() =>
      _EditRecurringTransactionSheetState();
}

class _EditRecurringTransactionSheetState
    extends State<EditRecurringTransactionSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelController;
  late TextEditingController _amountController;

  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _containerId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _labelController = TextEditingController(text: existing?.label ?? '');
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    _type = existing?.type ?? TransactionType.expense;
    _categoryId = existing?.category;
    _containerId = existing?.containerId;
    _frequency = existing?.frequency ?? RecurrenceFrequency.monthly;

    if (existing != null) {
      final parts = existing.startMonthKey.split('-');
      _startDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        existing.dayOfMonth,
      );
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final label = _labelController.text.trim();
    final startMonthKey =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}';

    if (widget.existing == null) {
      await RecurringTransactionsStore.add(
        RecurringTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          label: label,
          amount: amount,
          type: _type,
          category: _categoryId,
          containerId: _containerId,
          frequency: _frequency,
          dayOfMonth: _startDate.day,
          startMonthKey: startMonthKey,
        ),
      );
    } else {
      await RecurringTransactionsStore.update(
        widget.existing!.copyWith(
          label: label,
          amount: amount,
          type: _type,
          category: _categoryId,
          containerId: _containerId,
          frequency: _frequency,
          dayOfMonth: _startDate.day,
          startMonthKey: startMonthKey,
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final categories = CategoriesStore.all;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null
                    ? 'Nouvelle transaction récurrente'
                    : 'Modifier la récurrence',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Entrée'),
                  ),
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Sortie'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Libellé'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant'),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (parsed == null || parsed <= 0) ? 'Invalide' : null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String?>(
                initialValue: _containerId,
                decoration: const InputDecoration(
                  labelText: 'Support (optionnel)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ...containers.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _containerId = v),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Fréquence'),
                items: RecurrenceFrequency.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Première occurrence'),
                subtitle: Text(
                  '${_startDate.day.toString().padLeft(2, '0')}/'
                  '${_startDate.month.toString().padLeft(2, '0')}/'
                  '${_startDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Enregistrer'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
