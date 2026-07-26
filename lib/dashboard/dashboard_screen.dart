import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:stability/core/finance/transaction_type.dart';
import '../core/finance/transaction.dart';

import '../accounts/current_account.dart';
import '../accounts/account_selector_screen.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';

import '../core/finance/transactions_store.dart';
import '../core/finance/add_transaction_sheet.dart';
import '../core/finance/monthly_balances_store.dart';

import '../core/finance/categories_store.dart';
import '../core/finance/categories_screen.dart';

import '../recap/month_recap_screen.dart';
import '../archives/archives_screen.dart';
import '../core/archives/archives_store.dart';

import '../containers/containers_screen.dart';
import '../core/containers/containers_store.dart';
import '../core/containers/container_model.dart';

// ✅ AJOUTS UNIQUES
import '../core/containers/container_type.dart';
import '../core/containers/container_interests_screen.dart';

// 🔹 AJOUT ASSURANCE-VIE
import '../core/containers/container_insurance_life_screen.dart';
import '../core/containers/container_retirement_screen.dart';
import '../core/containers/container_investment_screen.dart';
import '../core/containers/capitalization_engine.dart';
import '../settings/settings_screen.dart';

import '../core/finance/active_month_store.dart';
import '../core/budget_rules/category_allocations_store.dart';
import '../core/budget_rules/budget_screen.dart';
import '../core/budget_rules/fifty_thirty_twenty_screen.dart';
import '../core/budget_rules/custom_mode_placeholder_screen.dart';
import '../accounts/management_mode.dart';
import '../core/finance/recurring_transactions_store.dart';
import '../core/finance/recurring_transactions_screen.dart';
import '../core/finance/transactions_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime get _now => DateTime.now();

  String _monthLabel(DateTime d) {
    const months = [
      'Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin',
      'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'
    ];
    return '${months[d.month - 1]} ${d.year.toString().substring(2)}';
  }

  DateTime _dateFromMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    final y = int.tryParse(parts[0]) ?? _now.year;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? _now.month;
    return DateTime(y, m, 1);
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _nextMonthKey(String monthKey) {
    final d = _dateFromMonthKey(monthKey);
    final next = DateTime(d.year, d.month + 1, 1);
    return '${next.year}-${next.month.toString().padLeft(2, '0')}';
  }

  Future<void> _safeClearBox(String boxName) async {
    try {
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      await box.clear();
    } catch (_) {}
  }

  Future<void> _devResetMontant() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('DEV — Reset montants'),
        content: const Text(
          'Supprime transactions + archives.\n'
          'Conserve catégories, supports, compte actif.\n'
          'Force le mois actif au mois courant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    TransactionsStore.clearAll();
    ArchivesStore.clear();
    await MonthlyBalancesStore.clearAll();

    ActiveMonthStore.set(_currentMonthKey());

    setState(() {});
  }

  Future<void> _devResetTotal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('DEV — RESET TOTAL'),
        content: const Text('⚠️ Supprime TOUT.\nRetour état premier lancement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('TOUT SUPPRIMER'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    TransactionsStore.clearAll();
    ArchivesStore.clear();
    CategoriesStore.clear();
    context.read<ContainersStore>().clearAll();
    await MonthlyBalancesStore.clearAll();
    await CategoryAllocationsStore.clearAll();
    await _safeClearBox('category_goals');
    RecurringTransactionsStore.clear();

    await _safeClearBox('active_month');
    await ActiveMonthStore.init();

    setState(() {});
  }

  void _openAddTransaction(
    TransactionType type, {
    Transaction? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        type: type,
        existing: existing,
      ),
    );
    setState(() {});
  }

  /// 🔹 Icône(s) du dashboard propres au mode de gestion du compte actif.
  /// C'est ici que l'interface s'adapte réellement selon la méthode choisie.
  List<Widget> _modeSpecificIcons() {
    switch (CurrentAccount.active.managementMode) {
      case ManagementMode.zeroBudget:
        return [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BudgetScreen(
                    monthKey: ActiveMonthStore.current,
                    monthLabel: _monthLabel(
                      _dateFromMonthKey(ActiveMonthStore.current),
                    ),
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ];

      case ManagementMode.fiftyThirtyTwenty:
        return [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FiftyThirtyTwentyScreen(
                    monthKey: ActiveMonthStore.current,
                    monthLabel: _monthLabel(
                      _dateFromMonthKey(ActiveMonthStore.current),
                    ),
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ];

      case ManagementMode.custom:
        return [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomModePlaceholderScreen(),
                ),
              );
            },
          ),
        ];

      case ManagementMode.free:
        return [];
    }
  }

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Entrée (revenu)'),
            onTap: () {
              Navigator.pop(context);
              _openAddTransaction(TransactionType.income);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove),
            title: const Text('Sortie (dépense)'),
            onTap: () {
              Navigator.pop(context);
              _openAddTransaction(TransactionType.expense);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Transfert'),
            onTap: () {
              Navigator.pop(context);
              _openAddTransaction(TransactionType.transfer);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloseMonth() async {
    final currentKey = ActiveMonthStore.current;
    final nextKey = _nextMonthKey(currentKey);

    final tx = TransactionsStore.transactionsForMonth(currentKey);
    if (tx.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clôturer le mois'),
        content: const Text(
          '• Les opérations pointées seront archivées\n'
          '• Les non pointées passeront au mois suivant (sans impacter le solde)\n'
          '• Aucune opération ne sera perdue',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    // ─────────────────────────────────────────
    // AUTO-POINTAGE DES TRANSACTIONS NON COURANTES
    // (considérées pointées par nature)
    // IMPORTANT: pas de getById (API inexistante)
    // ─────────────────────────────────────────
    final containersStore = context.read<ContainersStore>();

    final Set<String> currentAccountIds = containersStore.active
        .where((c) => c.type == ContainerType.currentAccount)
        .map((c) => c.id)
        .toSet();

    for (final t in tx) {
      final cid = t.containerId;
      if (cid == null) continue;

      final isCurrentAccount = currentAccountIds.contains(cid);

      if (!isCurrentAccount && !t.isCleared) {
        TransactionsStore.toggleCleared(t.id);
      }
    }
    // ─────────────────────────────────────────

    TransactionsStore.closeMonth(
      monthKey: currentKey,
      nextMonthKey: nextKey,
    );

    CategoryAllocationsStore.closeMonth(
      monthKey: currentKey,
      nextMonthKey: nextKey,
      categoryIds: CategoriesStore.all.map((c) => c.id).toList(),
    );

    ActiveMonthStore.set(nextKey);
    RecurringTransactionsStore.generateDueForMonth(nextKey);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = CurrentAccount.active;
    final containersStore = context.watch<ContainersStore>();
    final primary = containersStore.primaryCurrentAccount;

    final activeKey = ActiveMonthStore.current;
    final activeDate = _dateFromMonthKey(activeKey);

    final displayedBalance = primary == null
        ? null
        : MonthlyBalancesStore.getOpeningBalance(activeKey, primary.id) +
            TransactionsStore.transactionsForMonth(activeKey)
                .where((t) => t.containerId == primary.id && !t.isCarryOver)
                .fold<double>(
                  0,
                  (s, t) =>
                      t.type == TransactionType.income ? s + t.amount : s - t.amount,
                );

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _devResetMontant,
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: _devResetTotal,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionsListScreen(),
                ),
              );
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArchivesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.event_repeat),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecurringTransactionsScreen(),
                ),
              );
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.dashboard),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSelectorScreen(),
                ),
              );
              setState(() {});
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.account_balance),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContainersScreen()),
                  );
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.category),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CategoriesScreen()),
                  );
                },
              ),
              ..._modeSpecificIcons(),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: _openAddMenu,
              ),
              IconButton(
                icon: const Icon(Icons.pie_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MonthRecapScreen(
                        monthLabel: _monthLabel(activeDate),
                        transactions:
                            TransactionsStore.transactionsForMonth(activeKey),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.double_arrow),
                onPressed: _confirmCloseMonth,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  _monthLabel(activeDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayedBalance == null
                      ? '—'
                      : '${displayedBalance.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _DashboardContainersAndTransactions(
              monthKey: activeKey,
              onChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContainersAndTransactions extends StatefulWidget {
  final String monthKey;
  final VoidCallback onChanged;

  const _DashboardContainersAndTransactions({
    required this.monthKey,
    required this.onChanged,
  });

  @override
  State<_DashboardContainersAndTransactions> createState() =>
      _DashboardContainersAndTransactionsState();
}

class _DashboardContainersAndTransactionsState
    extends State<_DashboardContainersAndTransactions> {
  void _toggleCleared(Transaction t) {
    TransactionsStore.toggleCleared(t.id);
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editTransaction(Transaction t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(type: t.type, existing: t),
    );
    setState(() {});
    widget.onChanged();
  }

  Future<void> _deleteTransaction(Transaction t) async {
    TransactionsStore.remove(t.id);
    setState(() {});
    widget.onChanged();
  }

  Future<bool> _confirmDeleteTransaction(Transaction t) async {
    final isTransfer = t.transferId != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'opération'),
        content: Text(
          isTransfer
              ? 'Ce transfert sera supprimé des deux supports concernés.'
              : 'Cette opération sera définitivement supprimée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final transactions =
        TransactionsStore.transactionsForMonth(widget.monthKey);

    if (containers.isEmpty) {
      return const Center(child: Text('Aucun support'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Supports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ...containers.map((container) {
            // 🔹 Supports à écran dédié : ouverture directe au tap,
            // pas besoin d'avoir déjà une transaction dessus pour y accéder.
            if (container.type == ContainerType.insuranceLife ||
                container.type == ContainerType.retirementAccount ||
                container.type == ContainerType.investmentAccount) {
              return _DedicatedContainerTile(container: container);
            }

            final bool isPointable =
                container.type == ContainerType.currentAccount;

            // 🔹 Réserves permanentes (épargne, projet, espèces, autre) :
            // pas de cycle mensuel — on affiche tout l'historique du
            // support, sinon son contenu "disparaît" dès qu'un mois est
            // clôturé et que ses mouvements sont archivés.
            final bool isStandingReserve =
                container.type == ContainerType.savingsAccount ||
                    container.type == ContainerType.projectFund ||
                    container.type == ContainerType.cash ||
                    container.type == ContainerType.other;

            final containerTx = isStandingReserve
                ? TransactionsStore.historyByContainer(container.id)
                : transactions
                    .where((t) => t.containerId == container.id)
                    .toList();

            final opening = isStandingReserve
                ? 0.0
                : MonthlyBalancesStore.getOpeningBalance(
                    widget.monthKey,
                    container.id,
                  );

            final movements = containerTx
                .where((t) => !t.isCarryOver)
                .fold<double>(
                  0,
                  (sum, t) =>
                      t.type == TransactionType.income
                          ? sum + t.amount
                          : sum - t.amount,
                );

            final total = opening + movements;

            if (containerTx.isEmpty && opening == 0) {
              return ListTile(
                leading:
                    CircleAvatar(radius: 6, backgroundColor: container.color),
                title: Text(container.name),
                trailing: const Text('0.00 €'),
              );
            }

            final Map<String?, List<Transaction>> byCat = {};
            for (final t in containerTx) {
              byCat.putIfAbsent(t.category, () => []).add(t);
            }

            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              leading:
                  CircleAvatar(radius: 6, backgroundColor: container.color),

              // 🔹 BOUTONS CONTENEUR
              title: Row(
                children: [
                  Expanded(child: Text(container.name)),

                  if (container.type == ContainerType.savingsAccount)
                    IconButton(
                      icon: const Icon(Icons.trending_up),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ContainerInterestsScreen(container: container),
                          ),
                        );
                      },
                    ),

                ],
              ),

              trailing: Text(
                '${total.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: total > 0
                      ? Colors.green
                      : total < 0
                          ? Colors.red
                          : Colors.black,
                ),
              ),
              children: [
                ...byCat.entries.map((entry) {
                  final catId = entry.key;
                  final list = entry.value;

                  final catName = catId == null
                      ? 'Sans catégorie'
                      : (CategoriesStore.getById(catId)?.name ??
                          'Catégorie supprimée');

                  final amount = list
                      .where((t) => !t.isCarryOver)
                      .fold<double>(
                        0,
                        (s, t) => t.type == TransactionType.income
                            ? s + t.amount
                            : s - t.amount,
                      );

                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 32),
                    title: Text(catName),
                    trailing: Text(
                      '${amount.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: amount > 0
                            ? Colors.green
                            : amount < 0
                                ? Colors.red
                                : Colors.black,
                      ),
                    ),
                    children: [
                      ...list.map((t) {
                        final isIncome = t.type == TransactionType.income;
                        final title =
                            t.label.trim().isNotEmpty ? t.label : catName;

                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) => _confirmDeleteTransaction(t),
                          onDismissed: (_) => _deleteTransaction(t),
                          child: ListTile(
                            onTap: () => _editTransaction(t),
                            onLongPress: isPointable
                                ? () => _toggleCleared(t)
                                : null,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 48),
                            leading: Icon(
                              isIncome ? Icons.add : Icons.remove,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                            title: Row(
                              children: [
                                Flexible(child: Text(title)),
                                if (t.splitGroupId != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.call_split, size: 14),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${t.date.day.toString().padLeft(2, '0')}/'
                              '${t.date.month.toString().padLeft(2, '0')}/'
                              '${t.date.year}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPointable) ...[
                                  Icon(
                                    t.isCleared
                                        ? Icons.check_circle
                                        : Icons.schedule,
                                    size: 18,
                                    color: t.isCleared
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: t.isCarryOver
                                        ? Colors.grey
                                        : (isIncome ? Colors.green : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            );
          }),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Support avec écran dédié (assurance-vie, retraite, investissement) :
/// pas de liste de transactions sur le dashboard, un tap ouvre
/// directement l'écran de gestion, même si le support est encore vide.
class _DedicatedContainerTile extends StatelessWidget {
  final ContainerModel container;

  const _DedicatedContainerTile({required this.container});

  Widget _trailingValue() {
    if (container.type == ContainerType.investmentAccount) {
      final count =
          container.cryptoHoldings.length + container.stockHoldings.length;
      return Text(
        count == 0 ? 'Aucune position' : '$count position${count > 1 ? 's' : ''}',
        style: const TextStyle(color: Colors.grey),
      );
    }

    final configured = container.insuranceOpenedAt != null &&
        container.insuranceAnnualRate != null &&
        container.insuranceInterestMode != null;

    final calculated = configured
        ? CapitalizationEngine.computeValue(
            container: container,
            atDate: DateTime.now(),
          )
        : null;

    final displayed = container.insuranceCorrectedValue ?? calculated;

    return Text(
      displayed == null ? 'Non configuré' : '${displayed.toStringAsFixed(2)} €',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: displayed == null ? Colors.grey : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(radius: 6, backgroundColor: container.color),
      title: Text(container.name),
      subtitle: Text(container.type.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _trailingValue(),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        final Widget screen = switch (container.type) {
          ContainerType.insuranceLife =>
            ContainerInsuranceLifeScreen(container: container),
          ContainerType.retirementAccount =>
            ContainerRetirementScreen(container: container),
          ContainerType.investmentAccount =>
            ContainerInvestmentScreen(container: container),
          _ => throw StateError('Type non pris en charge'),
        };
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}
