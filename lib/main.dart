import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/sentry_config.dart';
import 'backend/supabase_config.dart';
import 'backend/auth_repository.dart';
import 'backend/cloud_account.dart';
import 'backend/cloud_accounts_repository.dart';
import 'accounts/auth_screen.dart';
import 'accounts/reset_password_screen.dart';
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
import 'core/finance/recurring_widget_service.dart';
import 'core/finance/recurring_overrides_store.dart';
import 'core/containers/interest_adjustments_store.dart';
import 'equity/account_members_store.dart';
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
  // Doit démarrer ici, avant runApp : sur le web, le SDK détecte un lien
  // de récupération de mot de passe dans l'URL dès `initialize`, bien
  // avant qu'AppRoot n'ait la moindre chance de se monter et de s'abonner
  // lui-même (l'écran de lancement tourne encore plusieurs secondes).
  AuthRepository.startListeningForPasswordRecovery();
  // Filet de sécurité : si `initialize` a déjà consommé l'évènement avant
  // même cet abonnement (le Stream broadcast ne le rejoue pas), on
  // retrouve l'information directement dans l'URL du navigateur.
  if (Uri.base.toString().contains('type=recovery')) {
    AuthRepository.isPasswordRecovery.value = true;
  }

  await SentryFlutter.init(
    (options) {
      // Désactivé en debug local (kDebugMode) pour ne pas polluer Sentry
      // avec des sessions de développement — actif en release (APK
      // installé, PWA) où se produisent les vrais plantages.
      options.dsn = kDebugMode ? null : SentryConfig.dsn;
      options.environment = kDebugMode ? 'development' : 'production';
      // Pas de suivi de performance (transactions) : uniquement les
      // plantages/erreurs, pour rester confortablement dans le plan
      // gratuit.
      options.tracesSampleRate = 0.0;
    },
    appRunner: () => runApp(const StabilityApp()),
  );
}

class StabilityApp extends StatelessWidget {
  const StabilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContainersStore()),
      ],
      child: ValueListenableBuilder<AppThemeChoice>(
        valueListenable: AppSettingsStore.themeChoiceNotifier,
        builder: (context, choice, _) {
          return ValueListenableBuilder<Color?>(
            valueListenable: AppSettingsStore.accentColorNotifier,
            builder: (context, accentColor, _) {
              final seedColor =
                  choice == AppThemeChoice.custom ? accentColor : null;
              final themeMode = switch (choice) {
                AppThemeChoice.light => ThemeMode.light,
                AppThemeChoice.dark => ThemeMode.dark,
                AppThemeChoice.custom => ThemeMode.system,
              };
              return MaterialApp(
                title: 'Stability',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(seedColor: seedColor),
                darkTheme: AppTheme.dark(seedColor: seedColor),
                themeMode: themeMode,
                home: const SplashGate(),
              );
            },
          );
        },
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
  await AccountMembersStore.init();
  await RecurringOverridesStore.init();

  // Rattrape les récurrences dues pour le mois actif (premier lancement
  // sur ce compte, ou nouveau gabarit créé alors que le mois était déjà
  // en cours).
  await RecurringTransactionsStore.generateDueForMonth(
    ActiveMonthStore.current,
    context.read<ContainersStore>(),
  );

  await RecurringWidgetService.refresh();
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
      return SplashScreen(
          onFinished: () => setState(() => _showSplash = false));
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
  bool _isPasswordRecovery = false;
  List<CloudAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _isPasswordRecovery = AuthRepository.isPasswordRecovery.value;
    _load();
    AuthRepository.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) return;
      _load();
    });
    AuthRepository.isPasswordRecovery.addListener(_onRecoveryChanged);
  }

  @override
  void dispose() {
    AuthRepository.isPasswordRecovery.removeListener(_onRecoveryChanged);
    super.dispose();
  }

  void _onRecoveryChanged() {
    if (mounted) {
      setState(() => _isPasswordRecovery = AuthRepository.isPasswordRecovery.value);
    }
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
    if (_isPasswordRecovery) {
      return ResetPasswordScreen(
        onDone: () {
          AuthRepository.isPasswordRecovery.value = false;
          _load();
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
