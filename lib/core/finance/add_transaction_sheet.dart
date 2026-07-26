import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stability/core/finance/finance.dart';
import 'package:stability/core/finance/active_month_store.dart';

import '../containers/containers_store.dart';

import 'categories_store.dart';
import 'categories_screen.dart';

/// Une ligne d'une transaction divisée sur plusieurs catégories.
class _SplitLine {
  String? categoryId;
  final TextEditingController amountController;

  _SplitLine({this.categoryId, String initialAmount = ''})
      : amountController = TextEditingController(text: initialAmount);

  void dispose() => amountController.dispose();
}

class AddTransactionSheet extends StatefulWidget {
  final TransactionType type;
  final Transaction? existing;
  final String? initialContainerId;

  const AddTransactionSheet({
    super.key,
    required this.type,
    this.existing,
    this.initialContainerId,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;

  DateTime _selectedDate = DateTime.now();

  String? _selectedCategoryId;
  String? _sourceContainerId;
  String? _destinationContainerId;

  bool _isSplit = false;
  final List<_SplitLine> _splitLines = [];

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _labelController = TextEditingController(text: existing?.label ?? '');
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );

    _selectedDate = existing?.date ?? DateTime.now();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));

    _selectedCategoryId = existing?.category;
    _sourceContainerId = existing?.containerId ?? widget.initialContainerId;
    _destinationContainerId = null;

    if (existing?.splitGroupId != null) {
      final siblings = TransactionsStore.all
          .where((t) => t.splitGroupId == existing!.splitGroupId)
          .toList();
      _isSplit = true;
      _splitLines.addAll(
        siblings.map(
          (t) => _SplitLine(
            categoryId: t.category,
            initialAmount: t.amount.toStringAsFixed(2),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    for (final line in _splitLines) {
      line.dispose();
    }
    super.dispose();
  }

  void _toggleSplit(bool value) {
    setState(() {
      _isSplit = value;
      if (value && _splitLines.isEmpty) {
        _splitLines.add(
          _SplitLine(
            categoryId: _selectedCategoryId,
            initialAmount: _amountController.text,
          ),
        );
        _splitLines.add(_SplitLine());
      } else if (!value) {
        for (final line in _splitLines) {
          line.dispose();
        }
        _splitLines.clear();
      }
    });
  }

  void _addSplitLine() {
    setState(() => _splitLines.add(_SplitLine()));
  }

  void _removeSplitLine(_SplitLine line) {
    if (_splitLines.length <= 2) return;
    setState(() {
      _splitLines.remove(line);
      line.dispose();
    });
  }

  double get _splitTotal {
    return _splitLines.fold<double>(0, (sum, line) {
      final v = double.tryParse(line.amountController.text.replaceAll(',', '.'));
      return sum + (v ?? 0);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _openCategoriesManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoriesScreen(),
      ),
    );
    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : _selectedCategoryId != null
            ? CategoriesStore.getById(_selectedCategoryId!)?.name ?? ''
            : '';

    final monthKey = ActiveMonthStore.current; // ✅ LIGNE CLÉ

    // ─────────────────────────────────────────
    // 🔀 DIVISÉ SUR PLUSIEURS CATÉGORIES
    // ─────────────────────────────────────────
    if (widget.type != TransactionType.transfer && _isSplit) {
      if (widget.existing != null) {
        TransactionsStore.remove(widget.existing!.id);
      }

      final splitGroupId = widget.existing?.splitGroupId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      for (int i = 0; i < _splitLines.length; i++) {
        final line = _splitLines[i];
        final lineAmount =
            double.parse(line.amountController.text.replaceAll(',', '.'));
        final lineLabel = label.isNotEmpty
            ? label
            : (line.categoryId != null
                ? CategoriesStore.getById(line.categoryId!)?.name ?? ''
                : '');

        TransactionsStore.add(
          Transaction(
            id: '${splitGroupId}_$i',
            label: lineLabel,
            amount: lineAmount,
            date: _selectedDate,
            type: widget.type,
            category: line.categoryId,
            containerId: _sourceContainerId,
            splitGroupId: splitGroupId,
            monthKey: monthKey,
          ),
        );
      }

      Navigator.pop(context);
      return;
    }

    final amount =
        double.parse(_amountController.text.replaceAll(',', '.'));

    // ─────────────────────────────────────────
    // 🔁 TRANSFERT
    // ─────────────────────────────────────────
    if (widget.type == TransactionType.transfer) {
      if (_sourceContainerId == null || _destinationContainerId == null) {
        return;
      }

      final transferId =
          DateTime.now().millisecondsSinceEpoch.toString();

      // SORTIE
      TransactionsStore.add(
        Transaction(
          id: '${transferId}_out',
          label: label,
          amount: amount,
          date: _selectedDate,
          type: TransactionType.expense,
          category: _selectedCategoryId,
          containerId: _sourceContainerId,
          transferId: transferId,
          monthKey: monthKey,
        ),
      );

      // ENTRÉE
      TransactionsStore.add(
        Transaction(
          id: '${transferId}_in',
          label: label,
          amount: amount,
          date: _selectedDate,
          type: TransactionType.income,
          category: _selectedCategoryId,
          containerId: _destinationContainerId,
          transferId: transferId,
          monthKey: monthKey,
        ),
      );
    }

    // ─────────────────────────────────────────
    // ➕ ENTRÉE / ➖ SORTIE CLASSIQUE
    // ─────────────────────────────────────────
    else {
      if (widget.existing == null) {
        TransactionsStore.add(
          Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            amount: amount,
            date: _selectedDate,
            type: widget.type,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            monthKey: monthKey,
          ),
        );
      } else if (widget.existing!.splitGroupId != null) {
        // Reconsolidation d'un split en une transaction unique.
        TransactionsStore.remove(widget.existing!.id);
        TransactionsStore.add(
          Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            amount: amount,
            date: _selectedDate,
            type: widget.type,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            monthKey: monthKey,
          ),
        );
      } else {
        TransactionsStore.updateTransaction(
          widget.existing!.copyWith(
            label: label,
            amount: amount,
            date: _selectedDate,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
          ),
        );
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final categories = CategoriesStore.all;
    final isTransfer = widget.type == TransactionType.transfer;

    final title = isTransfer
        ? 'Nouveau transfert'
        : widget.type == TransactionType.income
            ? 'Nouvelle entrée'
            : 'Nouvelle sortie';

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
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Libellé'),
              ),
              const SizedBox(height: 12),

              if (!isTransfer)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Diviser sur plusieurs catégories'),
                  value: _isSplit,
                  onChanged: _toggleSplit,
                ),

              if (!_isSplit) ...[
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Montant'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<String?>(
                initialValue: _sourceContainerId,
                decoration: InputDecoration(
                  labelText:
                      isTransfer ? 'Conteneur source' : 'Conteneur (optionnel)',
                ),
                items: [
                  if (!isTransfer)
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Aucun'),
                    ),
                  ...containers.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _sourceContainerId = value;
                  });
                },
                validator: isTransfer
                    ? (v) =>
                        v == null ? 'Conteneur source requis' : null
                    : null,
              ),
              const SizedBox(height: 12),

              if (isTransfer)
                DropdownButtonFormField<String?>(
                  initialValue: _destinationContainerId,
                  decoration: const InputDecoration(
                    labelText: 'Conteneur destination',
                  ),
                  items: containers
                      .where((c) => c.id != _sourceContainerId)
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _destinationContainerId = value;
                    });
                  },
                  validator: (v) =>
                      v == null ? 'Conteneur destination requis' : null,
                ),

              const SizedBox(height: 12),

              if (!_isSplit)
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                      labelText: 'Catégorie (optionnel)'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Aucune'),
                    ),
                    ...categories.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: '__manage__',
                      child: Text('➕ Gérer les catégories'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__manage__') {
                      _openCategoriesManager();
                    } else {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    }
                  },
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._splitLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String?>(
                                initialValue: line.categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Catégorie',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Aucune'),
                                  ),
                                  ...categories.map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => line.categoryId = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: line.amountController,
                                keyboardType: const TextInputType
                                    .numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Montant',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final parsed = double.tryParse(
                                    (v ?? '').replaceAll(',', '.'),
                                  );
                                  return (parsed == null || parsed <= 0)
                                      ? 'Invalide'
                                      : null;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _splitLines.length <= 2
                                  ? null
                                  : () => _removeSplitLine(line),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addSplitLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une catégorie'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total : ${_splitTotal.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date'),
                onTap: _pickDate,
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
