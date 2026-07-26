import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'dashboard/dashboard_screen.dart';

import 'core/finance/transactions_store.dart';
import 'core/finance/categories_store.dart';
import 'core/budget_rules/budget_rules_store.dart';
import 'core/archives/archives_store.dart';
import 'core/containers/containers_store.dart';
import 'core/finance/active_month_store.dart';
import 'core/finance/monthly_balances_store.dart'; // ✅ AJOUT
import 'core/budget_rules/category_allocations_store.dart';
import 'core/budget_rules/category_goals_store.dart';
import 'core/finance/recurring_transactions_store.dart';
import 'settings/app_settings_store.dart';
import 'accounts/current_account.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // 🔹 Stores init
  await TransactionsStore.init();
  await CategoriesStore.init();
  await BudgetRulesStore.init();
  await ArchivesStore.init();
  await ActiveMonthStore.init();
  await MonthlyBalancesStore.init(); // ✅ INDISPENSABLE
  await CategoryAllocationsStore.init();
  await CategoryGoalsStore.init();
  await RecurringTransactionsStore.init();
  await AppSettingsStore.init();
  CurrentAccount.restoreFromSettings();

  // Rattrape les récurrences dues pour le mois actif (premier lancement,
  // ou nouveau gabarit créé alors que le mois était déjà en cours).
  RecurringTransactionsStore.generateDueForMonth(ActiveMonthStore.current);

  runApp(const StabilityApp());
}

class StabilityApp extends StatelessWidget {
  const StabilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ContainersStore()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Stability',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
