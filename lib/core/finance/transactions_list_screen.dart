import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../containers/containers_store.dart';
import 'categories_store.dart';
import 'transaction.dart';
import 'transaction_type.dart';
import 'transactions_store.dart';
import 'add_transaction_sheet.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../theme/app_colors.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _categoryFilter;
  String? _containerFilter;
  TransactionType? _typeFilter;
  DateTimeRange? _dateRange;
  bool _sortDescending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _categoryFilter != null ||
      _containerFilter != null ||
      _typeFilter != null ||
      _dateRange != null;

  List<Transaction> _filtered() {
    var list = TransactionsStore.history();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((t) => t.label.toLowerCase().contains(q)).toList();
    }
    if (_categoryFilter != null) {
      list = list.where((t) => t.category == _categoryFilter).toList();
    }
    if (_containerFilter != null) {
      list = list.where((t) => t.containerId == _containerFilter).toList();
    }
    if (_typeFilter != null) {
      list = list.where((t) => t.type == _typeFilter).toList();
    }
    if (_dateRange != null) {
      list = list.where((t) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        return !d.isBefore(_dateRange!.start) && !d.isAfter(_dateRange!.end);
      }).toList();
    }

    list.sort((a, b) =>
        _sortDescending ? b.date.compareTo(a.date) : a.date.compareTo(b.date));

    return list;
  }

  Future<void> _openFilters() async {
    final categories = CategoriesStore.all;
    final containers = context.read<ContainersStore>().all;

    String? categoryFilter = _categoryFilter;
    String? containerFilter = _containerFilter;
    TransactionType? typeFilter = _typeFilter;
    DateTimeRange? dateRange = _dateRange;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtres',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TransactionType?>(
                  initialValue: typeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(
                      value: TransactionType.income,
                      child: Text('Entrées'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.expense,
                      child: Text('Sorties'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.transfer,
                      child: Text('Transferts'),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => typeFilter = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: containerFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Support'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    ...containers.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => containerFilter = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes')),
                    ...categories.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => categoryFilter = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Période'),
                  subtitle: Text(
                    dateRange == null
                        ? 'Toutes dates'
                        : '${_formatDate(dateRange!.start)} → '
                            '${_formatDate(dateRange!.end)}',
                  ),
                  trailing: Wrap(
                    children: [
                      if (dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setModalState(() => dateRange = null),
                        ),
                      const Icon(Icons.date_range),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: dateRange,
                    );
                    if (picked != null) {
                      setModalState(() => dateRange = picked);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            categoryFilter = null;
                            containerFilter = null;
                            typeFilter = null;
                            dateRange = null;
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _categoryFilter = categoryFilter;
                            _containerFilter = containerFilter;
                            _typeFilter = typeFilter;
                            _dateRange = dateRange;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _editTransaction(Transaction t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(type: t.type, existing: t),
    );
    setState(() {});
  }

  Future<bool> _confirmDelete(Transaction t) async {
    final isGrouped = t.transferId != null || t.splitGroupId != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'opération'),
        content: Text(
          isGrouped
              ? 'Les opérations liées (transfert ou split) seront aussi supprimées.'
              : 'Cette opération sera définitivement supprimée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Supprimer',
              style: TextStyle(color: context.appColors.negative),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().all;
    final transactions = _filtered();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(
                _sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: 'Trier par date',
            onPressed: () => setState(() => _sortDescending = !_sortDescending),
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _hasActiveFilters
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _openFilters,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.transactionsList),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par libellé...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('Aucune transaction trouvée'))
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      final isIncome = t.type == TransactionType.income;
                      final categoryName = t.category != null
                          ? CategoriesStore.getById(t.category!)?.name
                          : null;
                      final matchingContainers =
                          containers.where((c) => c.id == t.containerId);
                      final containerName = matchingContainers.isEmpty
                          ? null
                          : matchingContainers.first.name;

                      return Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: context.appColors.negative,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDelete(t),
                        onDismissed: (_) async {
                          await TransactionsStore.remove(t.id);
                          if (!mounted) return;
                          setState(() {});
                        },
                        child: ListTile(
                          onTap: () => _editTransaction(t),
                          leading: Icon(
                            isIncome ? Icons.add : Icons.remove,
                            color: isIncome
                                ? context.appColors.positive
                                : context.appColors.negative,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  t.label.trim().isNotEmpty
                                      ? t.label
                                      : (categoryName ?? '—'),
                                ),
                              ),
                              if (t.splitGroupId != null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.call_split, size: 14),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              _formatDate(t.date),
                              if (containerName != null) containerName,
                              if (categoryName != null) categoryName,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome
                                  ? context.appColors.positive
                                  : context.appColors.negative,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
