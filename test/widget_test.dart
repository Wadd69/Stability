import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stability/main.dart';
import 'package:stability/accounts/auth_screen.dart';
import 'package:stability/onboarding/welcome_screen.dart';
import 'package:stability/backend/supabase_config.dart';
import 'package:stability/core/finance/transactions_store.dart';
import 'package:stability/core/finance/categories_store.dart';
import 'package:stability/core/budget_rules/budget_rules_store.dart';
import 'package:stability/core/archives/archives_store.dart';
import 'package:stability/core/finance/active_month_store.dart';
import 'package:stability/core/finance/monthly_balances_store.dart';
import 'package:stability/core/budget_rules/category_allocations_store.dart';
import 'package:stability/settings/app_settings_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('stability_test');
    Hive.init(tempDir.path);

    await TransactionsStore.init();
    await CategoriesStore.init();
    await BudgetRulesStore.init();
    await ArchivesStore.init();
    await ActiveMonthStore.init();
    await MonthlyBalancesStore.init();
    await CategoryAllocationsStore.init();
    await AppSettingsStore.init();

    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  });

  tearDownAll(() async {
    tempDir.deleteSync(recursive: true);
  });

  // L'écran de lancement animé (SplashScreen) s'affiche ~4.2s avant de
  // laisser place à AppRoot — on avance le temps virtuel pour le dépasser.
  const splashDuration = Duration(milliseconds: 4300);

  testWidgets(
    'Premier lancement : l\'app démarre sur l\'écran de bienvenue',
    (tester) async {
      await tester.pumpWidget(const StabilityApp());
      await tester.pump();
      await tester.pump(splashDuration);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(WelcomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Après la bienvenue et sans session, on arrive sur la connexion',
    (tester) async {
      AppSettingsStore.setHasSeenWelcome(true);

      await tester.pumpWidget(const StabilityApp());
      await tester.pump();
      await tester.pump(splashDuration);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AuthScreen), findsOneWidget);

      AppSettingsStore.setHasSeenWelcome(false);
    },
  );
}
