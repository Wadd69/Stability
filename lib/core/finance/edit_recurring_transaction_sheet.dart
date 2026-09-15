import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../containers/container_model.dart';
import '../containers/containers_store.dart';
import '../../equity/account_members_store.dart';
import '../../equity/split_rule.dart';
import '../../equity/split_rule_editor.dart';
import 'categories_store.dart';
import 'recurring_transaction.dart';
import 'recurring_transactions_store.dart';
import 'recurring_widget_service.dart';
import 'transaction_type.dart';

/// Une ligne de destination d'un virement récurrent scindé — voir
/// [RecurringTransaction.destinationLegs].
class _DestLegLine {
  String? containerId;
  String? categoryId;
  final TextEditingController amountController;

  _DestLegLine({
    this.containerId,
    this.categoryId,
    String initialAmount = '',
  }) : amountController = TextEditingController(text: initialAmount);

  void dispose() => amountController.dispose();

  double get amount =>
      double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
}

class EditRecurringTransactionSheet extends StatefulWidget {
  final RecurringTransaction? existing;

  /// Pré-sélectionne une rubrique à la création (ignoré si [existing] est
  /// fourni) — utilisé depuis l'écran Rubriques pour créer directement une
  /// récurrente sans repasser par le sélecteur de rubrique.
  final String? initialCategoryId;

  const EditRecurringTransactionSheet({
    super.key,
    this.existing,
    this.initialCategoryId,
  });

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
  String? _destinationContainerId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  late DateTime _startDate;
  String? _transferError;
  SplitRule? _splitRule;
  bool _countsForNextMonth = false;

  bool _isDestSplit = false;
  final List<_DestLegLine> _destLegLines = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _labelController = TextEditingController(text: existing?.label ?? '');
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    _type = existing?.type ?? TransactionType.expense;
    _categoryId = existing?.category ?? widget.initialCategoryId;
    _containerId = existing?.containerId;
    _destinationContainerId = existing?.destinationContainerId;
    _frequency = existing?.frequency ?? RecurrenceFrequency.monthly;
    _splitRule = existing?.splitRule;
    _countsForNextMonth = existing?.countsForNextMonth ?? false;

    final legs = existing?.destinationLegs;
    if (legs != null && legs.isNotEmpty) {
      _isDestSplit = true;
      _destLegLines.addAll(
        legs.map(
          (l) => _DestLegLine(
            containerId: l.containerId,
            categoryId: l.category,
            initialAmount: l.amount.toStringAsFixed(2),
          ),
        ),
      );
    }

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
    for (final line in _destLegLines) {
      line.dispose();
    }
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

  void _toggleDestSplit(bool value) {
    setState(() {
      _isDestSplit = value;
      if (value && _destLegLines.isEmpty) {
        _destLegLines.add(
          _DestLegLine(
            containerId: _destinationContainerId,
            categoryId: _categoryId,
            initialAmount: _amountController.text,
          ),
        );
        _destLegLines.add(_DestLegLine());
      } else if (!value) {
        for (final line in _destLegLines) {
          line.dispose();
        }
        _destLegLines.clear();
      }
      _transferError = null;
    });
  }

  void _addDestLegLine() {
    setState(() => _destLegLines.add(_DestLegLine()));
  }

  void _removeDestLegLine(_DestLegLine line) {
    if (_destLegLines.length <= 2) return;
    setState(() {
      _destLegLines.remove(line);
      line.dispose();
    });
  }

  double get _destLegsSum =>
      _destLegLines.fold<double>(0, (sum, l) => sum + l.amount);

  /// Items d'un sélecteur de support — inclut toujours la valeur
  /// sélectionnée même si le support a été archivé depuis (sinon
  /// `DropdownButtonFormField` plante avec une assertion "value not in
  /// items").
  List<DropdownMenuItem<String?>> _containerItems(
    List<ContainerModel> active,
    String? selectedId,
  ) {
    final items = active
        .map(
          (c) => DropdownMenuItem<String?>(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();

    if (selectedId != null && !active.any((c) => c.id == selectedId)) {
      final all = context.read<ContainersStore>().all;
      String label = 'Support supprimé';
      try {
        label = '${all.firstWhere((c) => c.id == selectedId).name} (archivé)';
      } catch (_) {
        // Support totalement supprimé, pas seulement archivé.
      }
      items.add(
        DropdownMenuItem<String?>(
          value: selectedId,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return items;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_type == TransactionType.transfer) {
      if (_containerId == null) {
        setState(() => _transferError = 'Support source requis.');
        return;
      }
      if (_isDestSplit) {
        if (_destLegLines.any((l) => l.containerId == null || l.amount <= 0)) {
          setState(() =>
              _transferError = 'Complétez toutes les lignes destination.');
          return;
        }
        final amount =
            double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
        if ((_destLegsSum - amount).abs() > 0.005) {
          setState(() => _transferError =
              'Le total des destinations (${_destLegsSum.toStringAsFixed(2)} €) '
                  'doit égaler le montant (${amount.toStringAsFixed(2)} €).');
          return;
        }
        if (_destLegLines.any((l) => l.containerId == _containerId)) {
          setState(() => _transferError =
              'Une destination ne peut pas être le support source.');
          return;
        }
      } else {
        if (_destinationContainerId == null) {
          setState(() => _transferError = 'Support de destination requis.');
          return;
        }
        if (_containerId == _destinationContainerId) {
          setState(() =>
              _transferError = 'Les deux supports doivent être différents.');
          return;
        }
      }
    }
    setState(() => _transferError = null);

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final label = _labelController.text.trim();
    final startMonthKey =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}';
    final isTransfer = _type == TransactionType.transfer;
    final destination =
        isTransfer && !_isDestSplit ? _destinationContainerId : null;
    final destinationLegs = isTransfer && _isDestSplit
        ? _destLegLines
            .map((l) => RecurringTransferLeg(
                  containerId: l.containerId!,
                  category: l.categoryId,
                  amount: l.amount,
                ))
            .toList()
        : null;

    try {
      if (widget.existing == null) {
        await RecurringTransactionsStore.add(
          RecurringTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            amount: amount,
            type: _type,
            category: _categoryId,
            containerId: _containerId,
            destinationContainerId: destination,
            destinationLegs: destinationLegs,
            frequency: _frequency,
            dayOfMonth: _startDate.day,
            startMonthKey: startMonthKey,
            splitRule: _splitRule,
            countsForNextMonth: _countsForNextMonth,
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
            destinationContainerId: destination,
            destinationLegs: destinationLegs,
            clearDestinationLegs: destinationLegs == null,
            frequency: _frequency,
            dayOfMonth: _startDate.day,
            startMonthKey: startMonthKey,
            splitRule: _splitRule,
            clearSplitRule: _splitRule == null,
            countsForNextMonth: _countsForNextMonth,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'enregistrement : $e')),
      );
      return;
    }

    await RecurringWidgetService.refresh();

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _destLegLineRow(_DestLegLine line, List<Category> categories,
      List<ContainerModel> containers) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: line.containerId,
              decoration: const InputDecoration(labelText: 'Support'),
              items: _containerItems(containers, line.containerId),
              onChanged: (v) => setState(() => line.containerId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: line.categoryId,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucune')),
                ...categories.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => line.categoryId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant'),
              onChanged: (_) => setState(() => _transferError = null),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _destLegLines.length <= 2
                ? null
                : () => _removeDestLegLine(line),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final categories = CategoriesStore.all;
    final isTransfer = _type == TransactionType.transfer;

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
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Transfert'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _transferError = null;
                }),
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
                decoration: InputDecoration(
                  labelText: 'Montant',
                  helperText: isTransfer && _isDestSplit
                      ? 'Doit égaler le total des destinations ci-dessous.'
                      : null,
                ),
                validator: (v) {
                  final parsed =
                      double.tryParse((v ?? '').replaceAll(',', '.'));
                  return (parsed == null || parsed <= 0) ? 'Invalide' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _containerId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      isTransfer ? 'Support source' : 'Support (optionnel)',
                ),
                items: [
                  if (!isTransfer)
                    const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ..._containerItems(containers, _containerId),
                ],
                onChanged: (v) => setState(() => _containerId = v),
              ),
              if (isTransfer) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                      'Diviser la destination (plusieurs supports/catégories)'),
                  value: _isDestSplit,
                  onChanged: _toggleDestSplit,
                ),
                if (!_isDestSplit)
                  DropdownButtonFormField<String?>(
                    initialValue: _destinationContainerId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Support destination'),
                    items: _containerItems(
                      containers.where((c) => c.id != _containerId).toList(),
                      _destinationContainerId,
                    ),
                    onChanged: (v) =>
                        setState(() => _destinationContainerId = v),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._destLegLines.map(
                        (l) => _destLegLineRow(l, categories, containers),
                      ),
                      TextButton.icon(
                        onPressed: _addDestLegLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une destination'),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total : ${_destLegsSum.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
              if (_transferError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _transferError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (!isTransfer || !_isDestSplit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie (optionnel)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Aucune')),
                    ...categories.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
              SplitRuleEditor(
                initialValue: _splitRule,
                members: AccountMembersStore.all,
                allowInherit: true,
                onChanged: (r) => _splitRule = r,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _frequency,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fréquence'),
                items: RecurrenceFrequency.values
                    .map(
                        (f) => DropdownMenuItem(value: f, child: Text(f.label)))
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte pour le mois suivant'),
                subtitle: const Text(
                  'Cette occurrence (et son affichage dans la Prévision) '
                  'est rattachée au mois suivant plutôt qu\'au mois où '
                  'elle tombe réellement (ex: salaire de fin de mois qui '
                  'finance le mois suivant). La date réelle ne change pas, '
                  'mais le solde affiché de l\'app peut s\'écarter '
                  'temporairement de votre compte en banque jusqu\'à la '
                  'clôture du mois suivant.',
                ),
                value: _countsForNextMonth,
                onChanged: (v) => setState(() => _countsForNextMonth = v),
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
