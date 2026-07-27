import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'app_settings_store.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../accounts/current_account.dart';
import '../core/containers/containers_store.dart';
import '../core/finance/transactions_store.dart';
import '../core/finance/categories_store.dart';
import '../core/finance/active_month_store.dart';
import '../core/archives/archives_store.dart';
import '../core/finance/monthly_balances_store.dart';
import '../core/budget_rules/category_allocations_store.dart';
import '../core/finance/recurring_transactions_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: AppSettingsStore.finnhubApiKey ?? '');
  }

  void _save() {
    AppSettingsStore.setFinnhubApiKey(_controller.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé enregistrée')),
    );
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
        title: const Text('Réinitialiser les montants'),
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
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    TransactionsStore.clearAll();
    ArchivesStore.clear();
    await MonthlyBalancesStore.clearAll();

    ActiveMonthStore.set(_currentMonthKey());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Montants réinitialisés')),
    );
  }

  Future<void> _devResetTotal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tout réinitialiser'),
        content: const Text(
          '⚠️ Supprime absolument tout : transactions, supports, '
          'catégories, comptes. Retour à l\'état de premier lancement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appColors.negative,
            ),
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

    CurrentAccount.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppRoot()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.settings),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Actions / ETF',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pour suivre le cours d\'actions ou d\'ETF, il faut une clé API '
            'gratuite chez Finnhub (finnhub.io) : créez un compte gratuit, '
            'copiez votre clé personnelle et collez-la ici. Aucune carte '
            'bancaire n\'est demandée. La crypto, elle, ne demande aucune clé.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Clé API Finnhub',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            'Zone de développement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appColors.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Réservé aux tests — ces actions suppriment des données de '
            'façon définitive.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.warning,
              side: BorderSide(color: context.appColors.warning),
            ),
            onPressed: _devResetMontant,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Réinitialiser les montants du mois'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.negative,
              side: BorderSide(color: context.appColors.negative),
            ),
            onPressed: _devResetTotal,
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Tout réinitialiser'),
          ),
        ],
      ),
    );
  }
}
