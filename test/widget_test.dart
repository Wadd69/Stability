import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stability/main.dart';
import 'package:stability/accounts/auth_screen.dart';
import 'package:stability/onboarding/welcome_screen.dart';
import 'package:stability/backend/supabase_config.dart';
import 'package:stability/settings/app_settings_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Les données financières (transactions, catégories, supports...)
    // vivent désormais sur Supabase, scopées par compte actif — il n'y a
    // plus de store local à initialiser avant authentification. Seule
    // AppSettingsStore (préférences de cet appareil) reste locale (Hive).
    tempDir = Directory.systemTemp.createTempSync('stability_test');
    Hive.init(tempDir.path);
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
