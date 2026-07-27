import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/supabase_config.dart';
import 'backend/auth_repository.dart';
import 'backend/cloud_account.dart';
import 'backend/cloud_accounts_repository.dart';
import 'accounts/auth_screen.dart';
import 'onboarding/welcome_screen.dart';
import 'onboarding/splash_screen.dart';

import 'dashboard/dashboard_screen.dart';

import 'core/finance/transactions_store.dart';
import 'core/finance/categories_store.dart';
import 'core/archives/archives_store.dart';
import 'core/containers/containers_store.dart';
import 'core/finance/active_month_store.dart';
import 'core/finance/monthly_balances_store.dart';
import 'core/budget_rules/category_allocations_store.dart';
import 'core/budget_rules/category_goals_store.dart';
import 'core/finance/recurring_transactions_store.dart';
import 'core/containers/interest_adjustments_store.dart';
import 'settings/app_settings_store.dart';
import 'accounts/current_account.dart';
import 'accounts/create_account_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // 🔹 Préférences locales de cet appareil — les données financières ne
  // sont plus initialisées ici : elles vivent sur Supabase et dépendent
  // du compte actif, connu seulement après authentification (voir
  // AppRootState._load ci-dessous).
  await AppSettingsStore.init();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const StabilityApp());
}

class StabilityApp extends StatelessWidget {
  const StabilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContainersStore()),
      ],
      child: MaterialApp(
        title: 'Stability',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const SplashGate(),
      ),
    );
  }
}

/// Charge toutes les données financières du compte actif depuis Supabase —
/// à appeler après connexion et à chaque changement de compte actif (voir
/// AppRootState._load et DashboardScreen, au retour de AccountSelectorScreen
/// et CreateAccountScreen).
Future<void> loadAccountData(BuildContext context) async {
  await context.read<ContainersStore>().init();
  await CategoriesStore.init();
  await TransactionsStore.init();
  await ArchivesStore.init();
  await ActiveMonthStore.init();
  await MonthlyBalancesStore.init();
  await CategoryAllocationsStore.init();
  await CategoryGoalsStore.init();
  await RecurringTransactionsStore.init();
  await InterestAdjustmentsStore.init();

  // Rattrape les récurrences dues pour le mois actif (premier lancement
  // sur ce compte, ou nouveau gabarit créé alors que le mois était déjà
  // en cours).
  await RecurringTransactionsStore.generateDueForMonth(
    ActiveMonthStore.current,
  );
}

/// Affiche l'écran de lancement animé une fois au démarrage, puis laisse
/// place à [AppRoot] et sa logique de navigation habituelle (bienvenue,
/// connexion, création de compte, tableau de bord).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onFinished: () => setState(() => _showSplash = false));
    }
    return const AppRoot();
  }
}

/// Point d'entrée réel de l'app :
/// 1. Pas connecté → écran de connexion/inscription
/// 2. Connecté sans aucun compte → écran de création de compte
/// 3. Connecté avec au moins un compte → dashboard
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => AppRootState();
}

class AppRootState extends State<AppRoot> {
  bool _loading = true;
  List<CloudAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
    AuthRepository.onAuthStateChange.listen((_) => _load());
  }

  Future<void> _load() async {
    if (!AuthRepository.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _accounts = [];
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final accounts = await CloudAccountsRepository.fetchMyAccounts();
      await CurrentAccount.restoreFromSettings(accounts);

      if (CurrentAccount.hasActive && mounted) {
        await loadAccountData(context);
      }

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accounts = [];
        _loading = false;
      });
    }
  }

  void refresh() => _load();

  @override
  Widget build(BuildContext context) {
    if (!AppSettingsStore.hasSeenWelcome) {
      return WelcomeScreen(
        onContinue: () {
          AppSettingsStore.setHasSeenWelcome(true);
          setState(() {});
        },
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!AuthRepository.isAuthenticated) {
      return AuthScreen(onAuthenticated: refresh);
    }
    if (_accounts.isEmpty) {
      return CreateAccountScreen(onCreated: refresh);
    }
    return const DashboardScreen();
  }
}
