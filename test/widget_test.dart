import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:stability/main.dart';
import 'package:stability/dashboard/dashboard_screen.dart';
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
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('L\'app démarre et affiche le dashboard', (tester) async {
    await tester.pumpWidget(const StabilityApp());
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
