import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stability/core/finance/finance.dart';
import 'package:stability/core/finance/active_month_store.dart';

import '../containers/container_model.dart';
import '../containers/containers_store.dart';
import '../budget_rules/budget_automation_service.dart';
import '../../backend/auth_repository.dart';
import '../../equity/account_members_store.dart';

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

/// Une ligne d'un virement scindé (côté source ou destination).
/// [categoryId] n'est utilisé que côté destination.
class _TransferLegLine {
  String? containerId;
  String? categoryId;
  final TextEditingController amountController;

  _TransferLegLine({
    this.containerId,
    this.categoryId,
    String initialAmount = '',
  }) : amountController = TextEditingController(text: initialAmount);

  void dispose() => amountController.dispose();

  double get amount =>
      double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
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
  String? _paidByUserId;

  bool _isSplit = false;
  final List<_SplitLine> _splitLines = [];

  // Virement : détecté soit par widget.type, soit parce qu'on édite
  // une transaction qui fait partie d'un virement existant (bug historique :
  // les lignes stockées sont expense/income, jamais littéralement "transfer").
  late bool _isTransfer;
  bool _isSourceSplit = false;
  bool _isDestSplit = false;
  final List<_TransferLegLine> _sourceLegLines = [];
  final List<_TransferLegLine> _destLegLines = [];
  String? _transferError;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _isTransfer =
        widget.type == TransactionType.transfer || existing?.transferId != null;

    _labelController = TextEditingController(text: existing?.label ?? '');
    _amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );

    _selectedDate = existing?.date ?? DateTime.now();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));

    _selectedCategoryId = existing?.category;
    _sourceContainerId = existing?.containerId ?? widget.initialContainerId;
    _destinationContainerId = null;
    _paidByUserId = existing?.paidByUserId ?? AuthRepository.currentUser?.id;

    if (_isTransfer && existing?.transferId != null) {
      final legs = TransactionsStore.all
          .where((t) => t.transferId == existing!.transferId)
          .toList();
      final sourceLegs =
          legs.where((t) => t.type == TransactionType.expense).toList();
      final destLegs =
          legs.where((t) => t.type == TransactionType.income).toList();

      if (sourceLegs.length > 1) {
        _isSourceSplit = true;
        _sourceLegLines.addAll(
          sourceLegs.map(
            (t) => _TransferLegLine(
              containerId: t.containerId,
              initialAmount: t.amount.toStringAsFixed(2),
            ),
          ),
        );
      } else if (sourceLegs.isNotEmpty) {
        _sourceContainerId = sourceLegs.first.containerId;
      }

      if (destLegs.length > 1) {
        _isDestSplit = true;
        _destLegLines.addAll(
          destLegs.map(
            (t) => _TransferLegLine(
              containerId: t.containerId,
              categoryId: t.category,
              initialAmount: t.amount.toStringAsFixed(2),
            ),
          ),
        );
      } else if (destLegs.isNotEmpty) {
        _destinationContainerId = destLegs.first.containerId;
      }

      final total = sourceLegs.isNotEmpty
          ? sourceLegs.fold<double>(0, (s, t) => s + t.amount)
          : destLegs.fold<double>(0, (s, t) => s + t.amount);
      _amountController.text = total.toStringAsFixed(2);

      _selectedCategoryId = destLegs.isNotEmpty
          ? destLegs.first.category
          : (sourceLegs.isNotEmpty ? sourceLegs.first.category : null);
    } else if (existing?.splitGroupId != null) {
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
    for (final line in _sourceLegLines) {
      line.dispose();
    }
    for (final line in _destLegLines) {
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
      final v =
          double.tryParse(line.amountController.text.replaceAll(',', '.'));
      return sum + (v ?? 0);
    });
  }

  void _toggleSourceSplit(bool value) {
    setState(() {
      _isSourceSplit = value;
      if (value && _sourceLegLines.isEmpty) {
        _sourceLegLines.add(
          _TransferLegLine(
            containerId: _sourceContainerId,
            initialAmount: _amountController.text,
          ),
        );
        _sourceLegLines.add(_TransferLegLine());
      } else if (!value) {
        for (final line in _sourceLegLines) {
          line.dispose();
        }
        _sourceLegLines.clear();
      }
      _transferError = null;
    });
  }

  void _toggleDestSplit(bool value) {
    setState(() {
      _isDestSplit = value;
      if (value && _destLegLines.isEmpty) {
        _destLegLines.add(
          _TransferLegLine(
            containerId: _destinationContainerId,
            categoryId: _selectedCategoryId,
            initialAmount: _amountController.text,
          ),
        );
        _destLegLines.add(_TransferLegLine());
      } else if (!value) {
        for (final line in _destLegLines) {
          line.dispose();
        }
        _destLegLines.clear();
      }
      _transferError = null;
    });
  }

  void _addSourceLegLine() {
    setState(() => _sourceLegLines.add(_TransferLegLine()));
  }

  void _removeSourceLegLine(_TransferLegLine line) {
    if (_sourceLegLines.length <= 2) return;
    setState(() {
      _sourceLegLines.remove(line);
      line.dispose();
    });
  }

  void _addDestLegLine() {
    setState(() => _destLegLines.add(_TransferLegLine()));
  }

  void _removeDestLegLine(_TransferLegLine line) {
    if (_destLegLines.length <= 2) return;
    setState(() {
      _destLegLines.remove(line);
      line.dispose();
    });
  }

  double get _sourceLinesSum =>
      _sourceLegLines.fold<double>(0, (sum, l) => sum + l.amount);

  double get _destLinesSum =>
      _destLegLines.fold<double>(0, (sum, l) => sum + l.amount);

  // Le total d'un côté non scindé reprend le total de l'autre côté quand
  // celui-ci est scindé (un seul montant à saisir, jamais deux fois le
  // même chiffre) ; sinon on retombe sur le champ "Montant" classique.
  double get _sourceLegTotal {
    if (_isSourceSplit) return _sourceLinesSum;
    if (_isDestSplit) return _destLinesSum;
    return double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
  }

  double get _destLegTotal {
    if (_isDestSplit) return _destLinesSum;
    if (_isSourceSplit) return _sourceLinesSum;
    return double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
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

  Future<void> _saveTransfer(String label, String monthKey) async {
    final bothSplit = _isSourceSplit && _isDestSplit;
    final sourceTotal = _sourceLegTotal;
    final destTotal = _destLegTotal;

    if (bothSplit && (sourceTotal - destTotal).abs() > 0.005) {
      setState(() {
        _transferError =
            'Le total source (${sourceTotal.toStringAsFixed(2)} €) doit être '
            'égal au total destination (${destTotal.toStringAsFixed(2)} €).';
      });
      return;
    }

    if (_isSourceSplit &&
        _sourceLegLines.any((l) => l.containerId == null || l.amount <= 0)) {
      setState(() => _transferError = 'Complétez toutes les lignes source.');
      return;
    }
    if (_isDestSplit &&
        _destLegLines.any((l) => l.containerId == null || l.amount <= 0)) {
      setState(
          () => _transferError = 'Complétez toutes les lignes destination.');
      return;
    }
    if (!_isSourceSplit && _sourceContainerId == null) return;
    if (!_isDestSplit && _destinationContainerId == null) return;

    try {
      final existingTransferId = widget.existing?.transferId;
      if (existingTransferId != null) {
        await TransactionsStore.remove(widget.existing!.id);
      }
      final transferId = existingTransferId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // ── SOURCE ──
      if (_isSourceSplit) {
        final srcSplitGroupId = '${transferId}_src';
        for (int i = 0; i < _sourceLegLines.length; i++) {
          final line = _sourceLegLines[i];
          await TransactionsStore.add(
            Transaction(
              id: '${transferId}_out_$i',
              label: label,
              amount: line.amount,
              date: _selectedDate,
              type: TransactionType.expense,
              category: _selectedCategoryId,
              containerId: line.containerId,
              transferId: transferId,
              splitGroupId: srcSplitGroupId,
              monthKey: monthKey,
            ),
          );
        }
      } else {
        await TransactionsStore.add(
          Transaction(
            id: '${transferId}_out',
            label: label,
            amount: bothSplit ? sourceTotal : destTotal,
            date: _selectedDate,
            type: TransactionType.expense,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            transferId: transferId,
            monthKey: monthKey,
          ),
        );
      }

      // ── DESTINATION ──
      // La réduction du capital restant dû (support "Crédit") ne s'applique
      // qu'à la création d'un nouveau virement, jamais en édition — sinon
      // modifier le montant d'un virement existant la déclencherait à
      // nouveau et fausserait le capital restant (déjà réduit une première
      // fois lors de la création).
      final isNewTransfer = widget.existing == null;
      final containersStore = context.read<ContainersStore>();
      if (_isDestSplit) {
        final dstSplitGroupId = '${transferId}_dst';
        for (int j = 0; j < _destLegLines.length; j++) {
          final line = _destLegLines[j];
          await TransactionsStore.add(
            Transaction(
              id: '${transferId}_in_$j',
              label: label,
              amount: line.amount,
              date: _selectedDate,
              type: TransactionType.income,
              category: line.categoryId,
              containerId: line.containerId,
              transferId: transferId,
              splitGroupId: dstSplitGroupId,
              monthKey: monthKey,
            ),
          );
          if (isNewTransfer) {
            await BudgetAutomationService.applyCreditRepayment(
              containersStore,
              line.containerId,
              line.amount,
            );
          }
        }
      } else {
        final destAmount = bothSplit ? destTotal : sourceTotal;
        await TransactionsStore.add(
          Transaction(
            id: '${transferId}_in',
            label: label,
            amount: destAmount,
            date: _selectedDate,
            type: TransactionType.income,
            category: _selectedCategoryId,
            containerId: _destinationContainerId,
            transferId: transferId,
            monthKey: monthKey,
          ),
        );
        if (isNewTransfer) {
          await BudgetAutomationService.applyCreditRepayment(
            containersStore,
            _destinationContainerId,
            destAmount,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'enregistrement : $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : _selectedCategoryId != null
            ? CategoriesStore.getById(_selectedCategoryId!)?.name ?? ''
            : '';

    final monthKey = ActiveMonthStore.current; // ✅ LIGNE CLÉ

    // ─────────────────────────────────────────
    // 🔁 TRANSFERT (simple ou scindé, source et/ou destination)
    // ─────────────────────────────────────────
    if (_isTransfer) {
      await _saveTransfer(label, monthKey);
      return;
    }

    // ─────────────────────────────────────────
    // 🔀 DIVISÉ SUR PLUSIEURS CATÉGORIES
    // ─────────────────────────────────────────
    if (_isSplit) {
      try {
        if (widget.existing != null) {
          await TransactionsStore.remove(widget.existing!.id);
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

          await TransactionsStore.add(
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
              paidByUserId: _paidByUserId,
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

      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    // ─────────────────────────────────────────
    // ➕ ENTRÉE / ➖ SORTIE CLASSIQUE
    // ─────────────────────────────────────────
    try {
      if (widget.existing == null) {
        await TransactionsStore.add(
          Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            amount: amount,
            date: _selectedDate,
            type: widget.type,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            monthKey: monthKey,
            paidByUserId: _paidByUserId,
          ),
        );
      } else if (widget.existing!.splitGroupId != null) {
        // Reconsolidation d'un split en une transaction unique.
        await TransactionsStore.remove(widget.existing!.id);
        await TransactionsStore.add(
          Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            amount: amount,
            date: _selectedDate,
            type: widget.type,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            monthKey: monthKey,
            paidByUserId: _paidByUserId,
          ),
        );
      } else {
        await TransactionsStore.updateTransaction(
          widget.existing!.copyWith(
            label: label,
            amount: amount,
            date: _selectedDate,
            category: _selectedCategoryId,
            containerId: _sourceContainerId,
            paidByUserId: _paidByUserId,
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

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Items d'un sélecteur de support — inclut toujours la valeur
  /// sélectionnée même si le support a été archivé depuis (sinon
  /// `DropdownButtonFormField` plante avec une assertion "value not in
  /// items" à l'édition d'une ancienne transaction).
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

  Widget _transferLegLineRow({
    required _TransferLegLine line,
    required List categories,
    required List<ContainerModel> containers,
    required bool showCategory,
    required VoidCallback onRemove,
    required bool canRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: showCategory ? 2 : 3,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: line.containerId,
              decoration: const InputDecoration(labelText: 'Support'),
              items: _containerItems(containers, line.containerId),
              onChanged: (value) => setState(() => line.containerId = value),
            ),
          ),
          if (showCategory) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: line.categoryId,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                  ...categories.map<DropdownMenuItem<String?>>(
                    (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis)),
                  ),
                ],
                onChanged: (value) => setState(() => line.categoryId = value),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
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
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final categories = CategoriesStore.all;
    final isTransfer = _isTransfer;

    final title = isTransfer
        ? 'Nouveau transfert'
        : widget.type == TransactionType.income
            ? 'Nouvelle entrée'
            : 'Nouvelle sortie';

    return ConstrainedBox(
      // Hauteur plafonnée volontairement, même quand le clavier est
      // fermé : certains claviers/launchers (Xiaomi HyperOS notamment)
      // rapportent un espace disponible incorrect une fois le clavier
      // ouvert, ce qui peut laisser le bouton "Enregistrer" hors champ
      // sans que la zone ne devienne scrollable. En forçant une hauteur
      // maximale ici, le SingleChildScrollView est toujours réellement
      // scrollable, quel que soit ce que rapporte l'OS sur le clavier.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                if (isTransfer) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Diviser la source (plusieurs supports)'),
                    value: _isSourceSplit,
                    onChanged: _toggleSourceSplit,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Diviser la destination (plusieurs supports/catégories)'),
                    value: _isDestSplit,
                    onChanged: _toggleDestSplit,
                  ),
                ],
                if (!_isSplit &&
                    !(isTransfer && (_isSourceSplit || _isDestSplit))) ...[
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
                if (isTransfer && (_isSourceSplit || _isDestSplit)) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isSourceSplit && _isDestSplit
                          ? 'Source : ${_sourceLegTotal.toStringAsFixed(2)} € · '
                              'Destination : ${_destLegTotal.toStringAsFixed(2)} €'
                          : 'Total : ${(_isSourceSplit ? _sourceLegTotal : _destLegTotal).toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isTransfer)
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _sourceContainerId,
                    decoration:
                        const InputDecoration(labelText: 'Support (optionnel)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Aucun')),
                      ..._containerItems(containers, _sourceContainerId),
                    ],
                    onChanged: (value) {
                      setState(() => _sourceContainerId = value);
                    },
                  ),
                if (isTransfer && !_isSourceSplit) ...[
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _sourceContainerId,
                    decoration:
                        const InputDecoration(labelText: 'Support source'),
                    items: _containerItems(containers, _sourceContainerId),
                    onChanged: (value) {
                      setState(() => _sourceContainerId = value);
                    },
                    validator: (v) =>
                        v == null ? 'Support source requis' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (isTransfer && _isSourceSplit) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._sourceLegLines.map(
                        (line) => _transferLegLineRow(
                          line: line,
                          categories: categories,
                          containers: containers,
                          showCategory: false,
                          onRemove: () => _removeSourceLegLine(line),
                          canRemove: _sourceLegLines.length > 2,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addSourceLegLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un support source'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (isTransfer && !_isDestSplit) ...[
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _destinationContainerId,
                    decoration: const InputDecoration(
                      labelText: 'Support destination',
                    ),
                    items: _containerItems(
                      containers
                          .where((c) => c.id != _sourceContainerId)
                          .toList(),
                      _destinationContainerId,
                    ),
                    onChanged: (value) {
                      setState(() => _destinationContainerId = value);
                    },
                    validator: (v) =>
                        v == null ? 'Support destination requis' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (isTransfer && _isDestSplit) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._destLegLines.map(
                        (line) => _transferLegLineRow(
                          line: line,
                          categories: categories,
                          containers: containers,
                          showCategory: true,
                          onRemove: () => _removeDestLegLine(line),
                          canRemove: _destLegLines.length > 2,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addDestLegLine,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une destination'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_transferError != null) ...[
                  Text(
                    _transferError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_isSplit &&
                    !(isTransfer && (_isSourceSplit || _isDestSplit)))
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
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
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
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
                else if (!isTransfer)
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
                                  isExpanded: true,
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
                                        child: Text(c.name,
                                            overflow: TextOverflow.ellipsis),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
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
                  )
                else if (!_isDestSplit)
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                        labelText: 'Catégorie (optionnel)'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Aucune')),
                      ...categories.map(
                        (c) => DropdownMenuItem(
                            value: c.id,
                            child:
                                Text(c.name, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  ),
                if (!isTransfer && AccountMembersStore.all.length >= 2) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _paidByUserId,
                    decoration: const InputDecoration(labelText: 'Payé par'),
                    items: AccountMembersStore.all
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.displayName,
                                overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _paidByUserId = value);
                    },
                  ),
                ],
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
      ),
    );
  }
}
