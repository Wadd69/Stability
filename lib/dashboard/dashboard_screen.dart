import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stability/core/finance/transaction_type.dart';
import '../core/finance/transaction.dart';
import '../backend/realtime_account_events_service.dart';
import '../main.dart' show loadAccountData;

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
import '../core/budget_rules/budget_automation_service.dart';
import '../core/budget_rules/launch_month_budget_screen.dart';
import '../accounts/management_mode.dart';
import '../core/finance/recurring_transactions_store.dart';
import '../core/finance/recurring_transactions_screen.dart';
import '../core/finance/transactions_list_screen.dart';
import '../patrimoine/net_worth_screen.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _realtimeService = RealtimeAccountEventsService();
  StreamSubscription<AccountEvent>? _eventsSub;
  final List<AccountEvent> _recentEvents = [];
  String? _realtimeAccountId;

  @override
  void initState() {
    super.initState();
    _eventsSub = _realtimeService.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 20) {
          _recentEvents.removeRange(20, _recentEvents.length);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(event.message)),
      );
    });
    _syncRealtimeSubscription();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }

  /// (Ré)abonne le flux temps réel au compte actif s'il est partagé —
  /// à rappeler après un changement de compte actif.
  void _syncRealtimeSubscription() {
    final account = CurrentAccount.active;
    if (!account.isShared) {
      _realtimeService.unsubscribe();
      _realtimeAccountId = null;
      return;
    }
    if (_realtimeAccountId == account.id) return;
    _realtimeAccountId = account.id;
    _realtimeService.subscribe(account.id);
  }

  void _openActivityFeed() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: _recentEvents.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune activité récente sur ce compte.'),
              )
            : ListView(
                shrinkWrap: true,
                children: _recentEvents
                    .map(
                      (e) => ListTile(
                        leading: const Icon(Icons.notifications_none),
                        title: Text(e.message),
                        subtitle: Text(
                          '${e.at.hour.toString().padLeft(2, '0')}:'
                          '${e.at.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

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

  String _nextMonthKey(String monthKey) {
    final d = _dateFromMonthKey(monthKey);
    final next = DateTime(d.year, d.month + 1, 1);
    return '${next.year}-${next.month.toString().padLeft(2, '0')}';
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
            tooltip: 'Budget',
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
            tooltip: '50/30/20',
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
            tooltip: 'Mode personnalisé',
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

  Widget _buildDrawer() {
    final account = CurrentAccount.active;

    Widget destinationTile({
      required IconData icon,
      required String label,
      required Widget Function() screenBuilder,
      bool refreshOnReturn = false,
    }) {
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () async {
          Navigator.pop(context); // ferme le tiroir
          if (refreshOnReturn) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screenBuilder()),
            );
            setState(() {});
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screenBuilder()),
            );
          }
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.managementMode.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Expanded + ListView plutôt que Column + Spacer : le contenu
            // défile au lieu de déborder sur les écrans courts (paysage,
            // multi-fenêtre, texte agrandi).
            Expanded(
              child: ListView(
                children: [
                  destinationTile(
                    icon: Icons.insights,
                    label: 'Patrimoine',
                    screenBuilder: () => const NetWorthScreen(),
                  ),
                  destinationTile(
                    icon: Icons.receipt_long,
                    label: 'Transactions',
                    screenBuilder: () => const TransactionsListScreen(),
                    refreshOnReturn: true,
                  ),
                  destinationTile(
                    icon: Icons.archive,
                    label: 'Archives',
                    screenBuilder: () => ArchivesScreen(),
                  ),
                  destinationTile(
                    icon: Icons.event_repeat,
                    label: 'Transactions récurrentes',
                    screenBuilder: () => const RecurringTransactionsScreen(),
                    refreshOnReturn: true,
                  ),
                  destinationTile(
                    icon: Icons.settings,
                    label: 'Réglages',
                    screenBuilder: () => const SettingsScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  void _openBudgetAutomationMenu() {
    final monthKey = ActiveMonthStore.current;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bolt),
            title: const Text('Lancer le budget du mois'),
            subtitle: const Text(
              'Crée les virements automatiques vers vos supports configurés',
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LaunchMonthBudgetScreen(
                    monthKey: monthKey,
                    monthLabel: _monthLabel(_dateFromMonthKey(monthKey)),
                  ),
                ),
              );
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.done_all),
            title: const Text('Valider les virements'),
            subtitle: const Text(
              'Marque comme pointés tous les virements du budget du mois',
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmValidateTransfers(monthKey);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmValidateTransfers(String monthKey) async {
    if (!BudgetAutomationService.hasPendingTransfers(monthKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun virement en attente ce mois-ci.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider les virements'),
        content: const Text(
          'Tous les virements du budget du mois seront marqués comme '
          'pointés. Vous pourrez toujours en modifier un individuellement '
          'ensuite.',
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

    if (ok != true) return;
    if (!mounted) return;

    final count = await BudgetAutomationService.validateTransfers(monthKey);
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count virement${count > 1 ? 's' : ''} validé${count > 1 ? 's' : ''}.')),
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
        await TransactionsStore.toggleCleared(t.id);
      }
    }
    // ─────────────────────────────────────────

    await TransactionsStore.closeMonth(
      monthKey: currentKey,
      nextMonthKey: nextKey,
    );

    await CategoryAllocationsStore.closeMonth(
      monthKey: currentKey,
      nextMonthKey: nextKey,
      categoryIds: CategoriesStore.all.map((c) => c.id).toList(),
    );

    await ActiveMonthStore.set(nextKey);
    await RecurringTransactionsStore.generateDueForMonth(nextKey);

    if (!mounted) return;
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
            tooltip: 'Aide',
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
            tooltip: 'Changer de compte',
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSelectorScreen(),
                ),
              );
              if (!mounted) return;
              await loadAccountData(context);
              if (!mounted) return;
              _syncRealtimeSubscription();
              setState(() {});
            },
          ),
          if (account.isShared)
            IconButton(
              tooltip: 'Activité du compte',
              icon: Badge(
                isLabelVisible: _recentEvents.isNotEmpty,
                label: Text('${_recentEvents.length}'),
                child: const Icon(Icons.notifications_none),
              ),
              onPressed: _openActivityFeed,
            ),
        ],
      ),
      drawer: _buildDrawer(),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            // Chaque icône est enveloppée dans un Expanded : sur un écran de
            // téléphone étroit, elles se compressent plutôt que de déborder
            // horizontalement (5 à 7 icônes selon le mode de gestion).
            children: [
              IconButton(
                tooltip: 'Supports',
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
                tooltip: 'Catégories',
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
                tooltip: 'Automatisation budget',
                icon: const Icon(Icons.bolt),
                onPressed: _openBudgetAutomationMenu,
              ),
              IconButton(
                tooltip: 'Ajouter',
                icon: const Icon(Icons.add_circle),
                onPressed: _openAddMenu,
              ),
              IconButton(
                tooltip: 'Récap du mois',
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
                tooltip: 'Clôturer le mois',
                icon: const Icon(Icons.double_arrow),
                onPressed: _confirmCloseMonth,
              ),
            ].map((icon) => Expanded(child: icon)).toList(),
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
  Future<void> _toggleCleared(Transaction t) async {
    await TransactionsStore.toggleCleared(t.id);
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editTransaction(Transaction t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(type: t.type, existing: t),
    );
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  Future<void> _deleteTransaction(Transaction t) async {
    await TransactionsStore.remove(t.id);
    if (!mounted) return;
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
                      ? context.appColors.positive
                      : total < 0
                          ? context.appColors.negative
                          : Theme.of(context).colorScheme.onSurface,
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
                            ? context.appColors.positive
                            : amount < 0
                                ? context.appColors.negative
                                : Theme.of(context).colorScheme.onSurface,
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
                            color: context.appColors.negative,
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
                              color: isIncome
                                  ? context.appColors.positive
                                  : context.appColors.negative,
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
                                        ? context.appColors.positive
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: t.isCarryOver
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : (isIncome
                                            ? context.appColors.positive
                                            : context.appColors.negative),
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

  Widget _trailingValue(BuildContext context) {
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;

    if (container.type == ContainerType.investmentAccount) {
      final count =
          container.cryptoHoldings.length + container.stockHoldings.length;
      return Text(
        count == 0 ? 'Aucune position' : '$count position${count > 1 ? 's' : ''}',
        style: TextStyle(color: neutral),
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
        color: displayed == null ? neutral : null,
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
          _trailingValue(context),
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
