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
import '../core/finance/transaction_analysis.dart';
import '../core/containers/container_model.dart';

// ✅ AJOUTS UNIQUES
import '../core/containers/container_type.dart';
import '../core/containers/container_interests_screen.dart';

// 🔹 AJOUT ASSURANCE-VIE
import '../core/containers/container_insurance_life_screen.dart';
import '../core/containers/container_retirement_screen.dart';
import '../core/containers/container_investment_screen.dart';
import '../core/containers/container_credit_screen.dart';
import '../core/containers/capitalization_engine.dart';
import '../settings/settings_screen.dart';
import '../settings/beta_feedback_screen.dart';

import '../core/finance/active_month_store.dart';
import '../core/budget_rules/category_allocations_store.dart';
import '../core/budget_rules/budget_screen.dart';
import '../core/budget_rules/fifty_thirty_twenty_screen.dart';
import '../core/budget_rules/pay_yourself_first_screen.dart';
import '../core/budget_rules/custom_mode_placeholder_screen.dart';
import '../accounts/management_mode.dart';
import '../core/finance/recurring_transactions_store.dart';
import '../core/finance/recurring_transactions_screen.dart';
import '../core/finance/recurring_widget_service.dart';
import '../core/finance/transactions_list_screen.dart';
import '../patrimoine/net_worth_screen.dart';
import '../theme/app_colors.dart';
import '../settings/app_settings_store.dart';
import '../onboarding/dashboard_tutorial_screen.dart';
import '../shared/category_pie_chart.dart';
import '../equity/equity_hub_screen.dart';
import 'forecast_screen.dart';

/// Catalogue des blocs optionnels affichables sur le dashboard, activables
/// et réordonnables depuis "Personnaliser le dashboard" (tiroir latéral).
const Map<String, String> kDashboardBlockLabels = {
  'alert': 'Alerte de dépassement de budget',
  'pie': 'Mini camembert des dépenses du mois',
  'recurring': 'Transactions récurrentes',
};

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

    // Mini-tuto une seule fois, à la toute première arrivée sur le
    // dashboard (juste après la création du premier compte) — pas liée à
    // la création d'un support en particulier.
    if (!AppSettingsStore.hasSeenDashboardTutorial) {
      AppSettingsStore.setHasSeenDashboardTutorial(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardTutorialScreen()),
        );
      });
    }
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
      'Janv.',
      'Févr.',
      'Mars',
      'Avr.',
      'Mai',
      'Juin',
      'Juil.',
      'Août',
      'Sept.',
      'Oct.',
      'Nov.',
      'Déc.'
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

  /// Ouvre l'écran de budget propre au mode de gestion actif (budget base
  /// zéro ou 50/30/20) — utilisé à la fois par l'icône de navigation et par
  /// la bannière de dépassement du dashboard.
  void _openModeBudgetScreen() {
    switch (CurrentAccount.active.managementMode) {
      case ManagementMode.zeroBudget:
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
        return;
      case ManagementMode.fiftyThirtyTwenty:
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
        return;
      case ManagementMode.payYourselfFirst:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayYourselfFirstScreen(
              monthKey: ActiveMonthStore.current,
              monthLabel: _monthLabel(
                _dateFromMonthKey(ActiveMonthStore.current),
              ),
            ),
          ),
        ).then((_) => setState(() {}));
        return;
      case ManagementMode.free:
      case ManagementMode.custom:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CategoriesScreen()),
        ).then((_) => setState(() {}));
        return;
    }
  }

  /// Rubriques (budget base zéro ou budget mensuel facultatif en mode libre/
  /// personnalisé) ou enveloppes (50/30/20) en dépassement ce mois-ci, pour
  /// la bannière d'alerte du dashboard.
  List<String> _overBudgetLines() {
    final activeKey = ActiveMonthStore.current;

    switch (CurrentAccount.active.managementMode) {
      case ManagementMode.zeroBudget:
        return CategoriesStore.all
            .map((c) => MapEntry(
                c, CategoryAllocationsStore.remaining(activeKey, c.id)))
            .where((e) => e.value < 0)
            .map((e) => '${e.key.name} (${e.value.toStringAsFixed(0)} €)')
            .toList();

      case ManagementMode.fiftyThirtyTwenty:
        final income = CategoryAllocationsStore.getPlannedIncome(activeKey);
        if (income <= 0) return [];

        final spentByBucket = <String, double>{};
        for (final t in TransactionsStore.transactionsForMonth(activeKey).where(
            (t) => t.type == TransactionType.expense && t.transferId == null)) {
          final bucketId = t.category != null
              ? CategoriesStore.getById(t.category!)?.bucketId
              : null;
          if (bucketId == null) continue;
          spentByBucket[bucketId] = (spentByBucket[bucketId] ?? 0) + t.amount;
        }

        return CurrentAccount.active.effectiveBuckets.where((b) {
          final target = income * b.targetShare;
          return (spentByBucket[b.id] ?? 0) > target;
        }).map((b) {
          final target = income * b.targetShare;
          final over = (spentByBucket[b.id] ?? 0) - target;
          return '${b.name} (+${over.toStringAsFixed(0)} €)';
        }).toList();

      case ManagementMode.free:
      case ManagementMode.payYourselfFirst:
      case ManagementMode.custom:
        // Pas d'allocation obligatoire ici : seules les rubriques où
        // l'utilisateur a défini un budget mensuel facultatif (via l'écran
        // Rubriques) sont prises en compte, sinon tout apparaîtrait comme
        // "dépassé" par défaut.
        return CategoriesStore.all
            .map((c) => MapEntry(
                c, CategoryAllocationsStore.getAllocated(activeKey, c.id)))
            .where((e) => e.value > 0)
            .map((e) => MapEntry(
                e.key, CategoryAllocationsStore.remaining(activeKey, e.key.id)))
            .where((e) => e.value < 0)
            .map((e) => '${e.key.name} (${e.value.toStringAsFixed(0)} €)')
            .toList();
    }
  }

  /// Construit le bloc optionnel [id] pour le dashboard, ou `null` s'il n'y
  /// a rien à afficher (ex: alerte sans dépassement ce mois-ci).
  Widget? _buildDashboardBlock({
    required String id,
    required List<String> overBudget,
    required String activeKey,
  }) {
    switch (id) {
      case 'alert':
        if (overBudget.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openModeBudgetScreen,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.appColors.negative.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.appColors.negative,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget dépassé : ${overBudget.join(' · ')}',
                      style: TextStyle(
                        color: context.appColors.negative,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case 'pie':
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: CategoryPieChart(
            transactions: TransactionAnalysis.filterForAnalysis(
              TransactionsStore.transactionsForMonth(activeKey),
              context.read<ContainersStore>(),
            ),
            mode: PieChartMode.expenses,
          ),
        );

      case 'recurring':
        final active =
            RecurringTransactionsStore.all.where((r) => r.active).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecurringTransactionsScreen(),
                ),
              );
              if (!mounted) return;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_repeat),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      active.isEmpty
                          ? 'Aucune transaction récurrente configurée'
                          : '${active.length} transaction'
                              '${active.length > 1 ? 's' : ''} récurrente'
                              '${active.length > 1 ? 's' : ''} active'
                              '${active.length > 1 ? 's' : ''}',
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );

      default:
        return null;
    }
  }

  /// Ouvre le sélecteur de blocs optionnels du dashboard : activer/désactiver
  /// et réordonner (glisser-déposer). Enregistré localement sur l'appareil.
  Future<void> _openDashboardCustomization() async {
    final order = List<String>.from(AppSettingsStore.dashboardBlocks);
    for (final id in kDashboardBlockLabels.keys) {
      if (!order.contains(id)) order.add(id);
    }
    final enabled = AppSettingsStore.dashboardBlocks.toSet();

    final allContainers = context.read<ContainersStore>().active;
    final hiddenContainers =
        Set<String>.from(AppSettingsStore.dashboardHiddenContainerIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          builder: (context, scrollController) => SafeArea(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                // Poignée visuelle : indique que la feuille se glisse pour
                // voir plus de contenu (pas évident sans elle).
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Personnaliser le dashboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Activez les blocs à afficher et glissez-les pour '
                    'choisir leur ordre.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  height: order.length * 64.0,
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setModalState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = order.removeAt(oldIndex);
                        order.insert(newIndex, id);
                      });
                    },
                    children: [
                      for (final entry in order.asMap().entries)
                        ListTile(
                          key: ValueKey(entry.value),
                          // Le handle est le seul point de départ du glisser
                          // : le laisser sur toute la ligne entre en
                          // conflit avec le geste du Switch et empêche de
                          // faire glisser les lignes qui suivent.
                          leading: ReorderableDragStartListener(
                            index: entry.key,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Text(kDashboardBlockLabels[entry.value] ??
                              entry.value),
                          trailing: Switch(
                            value: enabled.contains(entry.value),
                            onChanged: (v) => setModalState(() {
                              if (v) {
                                enabled.add(entry.value);
                              } else {
                                enabled.remove(entry.value);
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                if (allContainers.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Supports affichés',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Choisissez les supports visibles dans la liste du '
                      'dashboard. Ça n\'affecte que l\'affichage : rien '
                      'n\'est supprimé ni exclu des calculs.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  for (final c in allContainers)
                    SwitchListTile(
                      title: Text(c.name),
                      value: !hiddenContainers.contains(c.id),
                      onChanged: (v) => setModalState(() {
                        if (v) {
                          hiddenContainers.remove(c.id);
                        } else {
                          hiddenContainers.add(c.id);
                        }
                      }),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        AppSettingsStore.setDashboardBlocks(
                          order.where(enabled.contains).toList(),
                        );
                        AppSettingsStore.setDashboardHiddenContainerIds(
                          hiddenContainers,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  /// Icône(s) du dashboard propres au mode de gestion du compte actif.
  List<Widget> _modeSpecificIcons() {
    switch (CurrentAccount.active.managementMode) {
      case ManagementMode.zeroBudget:
        return [
          IconButton(
            tooltip: 'Budget',
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: _openModeBudgetScreen,
          ),
        ];

      case ManagementMode.fiftyThirtyTwenty:
        return [
          IconButton(
            tooltip: 'Pourcentages personnalisés',
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: _openModeBudgetScreen,
          ),
        ];

      case ManagementMode.payYourselfFirst:
        return [
          IconButton(
            tooltip: 'Paie-toi en premier',
            icon: const Icon(Icons.savings_outlined),
            onPressed: _openModeBudgetScreen,
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
                  if (account.isShared)
                    destinationTile(
                      icon: Icons.balance,
                      label: 'Équité',
                      screenBuilder: () => const EquityHubScreen(),
                      refreshOnReturn: true,
                    ),
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize),
                    title: const Text('Personnaliser le dashboard'),
                    onTap: () {
                      Navigator.pop(context);
                      _openDashboardCustomization();
                    },
                  ),
                  destinationTile(
                    icon: Icons.feedback_outlined,
                    label: 'Bêta & retours',
                    screenBuilder: () => const BetaFeedbackScreen(),
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

  Future<void> _confirmCloseMonth() async {
    final currentKey = ActiveMonthStore.current;
    final nextKey = _nextMonthKey(currentKey);

    final tx = TransactionsStore.transactionsForMonth(currentKey);

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

    Future<void> runCloseMonth() async {
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
        containersStore: containersStore,
      );

      await CategoryAllocationsStore.closeMonth(
        monthKey: currentKey,
        nextMonthKey: nextKey,
        categoryIds: CategoriesStore.all.map((c) => c.id).toList(),
      );

      await ActiveMonthStore.set(nextKey);
      await RecurringTransactionsStore.generateDueForMonth(
        nextKey,
        containersStore,
      );
      await RecurringWidgetService.refresh();
    }

    try {
      await runCloseMonth();
    } catch (e) {
      // Premier essai après une longue inactivité de l'app : rejet RLS
      // ponctuel observé (le second essai, identique, passe toujours).
      // Les étapes ci-dessus sont sans effet si déjà appliquées (on ne
      // repointe pas ce qui l'est déjà), donc un nouvel essai complet est
      // sûr. Si ça échoue à nouveau, on affiche l'erreur réelle.
      if (e.toString().contains('row-level security')) {
        try {
          await runCloseMonth();
          if (!mounted) return;
          setState(() {});
          return;
        } catch (e2) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Échec de la clôture du mois'),
              content: SelectableText(e2.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          setState(() {});
          return;
        }
      }

      // La clôture touche plusieurs stores en plusieurs appels réseau
      // successifs : sans ça, un échec au milieu de la séquence (ex: perte
      // réseau) échouait silencieusement, sans indice sur ce qui avait
      // réellement été appliqué ou non.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Échec de la clôture du mois'),
          content: SelectableText(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

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
                  (s, t) => t.type == TransactionType.income
                      ? s + t.amount
                      : s - t.amount,
                );

    final overBudget = _overBudgetLines();

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
                tooltip: 'Prévision du mois suivant',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForecastScreen()),
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
      body: SingleChildScrollView(
        child: Column(
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
            ...AppSettingsStore.dashboardBlocks
                .map((id) => _buildDashboardBlock(
                      id: id,
                      overBudget: overBudget,
                      activeKey: activeKey,
                    ))
                .whereType<Widget>(),
            const Divider(),
            _DashboardContainersAndTransactions(
              monthKey: activeKey,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
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
    final allContainers = context.watch<ContainersStore>().active;
    final hidden = AppSettingsStore.dashboardHiddenContainerIds;
    final containers =
        allContainers.where((c) => !hidden.contains(c.id)).toList();
    final transactions =
        TransactionsStore.transactionsForMonth(widget.monthKey);

    if (allContainers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Aucun support')),
      );
    }
    if (containers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tous les supports sont masqués sur ce dashboard.\n'
            'Réglez-les depuis "Personnaliser le dashboard".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
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
              container.type == ContainerType.investmentAccount ||
              container.type == ContainerType.credit) {
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

          final movements =
              containerTx.where((t) => !t.isCarryOver).fold<double>(
                    0,
                    (sum, t) => t.type == TransactionType.income
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
            leading: CircleAvatar(radius: 6, backgroundColor: container.color),

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

                final amount = list.where((t) => !t.isCarryOver).fold<double>(
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
                          onLongPress:
                              isPointable ? () => _toggleCleared(t) : null,
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
        count == 0
            ? 'Aucune position'
            : '$count position${count > 1 ? 's' : ''}',
        style: TextStyle(color: neutral),
      );
    }

    if (container.type == ContainerType.credit) {
      final remaining = container.creditRemainingBalance;
      return Text(
        remaining == null
            ? 'Non configuré'
            : '-${remaining.toStringAsFixed(2)} €',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: remaining == null ? neutral : context.appColors.negative,
        ),
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
          ContainerType.credit => ContainerCreditScreen(container: container),
          _ => throw StateError('Type non pris en charge'),
        };
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}
