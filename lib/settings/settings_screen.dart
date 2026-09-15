import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_settings_store.dart';
import '../accounts/account_security_screen.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../shared/color_wheel_picker.dart';
import '../main.dart';
import '../accounts/current_account.dart';
import '../core/containers/containers_store.dart';
import '../core/finance/transactions_store.dart';
import '../core/finance/categories_store.dart';
import '../core/finance/active_month_store.dart';
import '../core/archives/archives_store.dart';
import '../core/finance/monthly_balances_store.dart';
import '../core/budget_rules/category_allocations_store.dart';
import '../core/budget_rules/category_goals_store.dart';
import '../core/finance/recurring_transactions_store.dart';
import '../core/backup/backup_service.dart';

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

  /// Demande une phrase de passe à l'utilisateur (création ou
  /// confirmation) — utilisée pour chiffrer/déchiffrer un fichier de
  /// sauvegarde, jamais stockée nulle part.
  Future<String?> _askPassphrase({
    required String title,
    required String helperText,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Phrase de passe',
            helperText: helperText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    final passphrase = await _askPassphrase(
      title: 'Chiffrer la sauvegarde',
      helperText: 'Requise pour restaurer ce fichier plus tard. '
          'À retenir : elle n\'est stockée nulle part.',
    );
    if (passphrase == null || passphrase.isEmpty) return;
    if (!mounted) return;

    try {
      final path = await BackupService.exportToFile(passphrase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sauvegarde créée : $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la sauvegarde : $e')),
      );
    }
  }

  Future<void> _pickAndRestoreBackup() async {
    final backups = await BackupService.listBackups();
    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune sauvegarde trouvée dans ~/StabilityBackups'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<File>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: backups.map((f) {
            final modified = f.statSync().modified;
            String p(int n) => n.toString().padLeft(2, '0');
            return ListTile(
              leading: const Icon(Icons.restore),
              title: Text(f.uri.pathSegments.last),
              subtitle: Text(
                '${p(modified.day)}/${p(modified.month)}/${modified.year} '
                'à ${p(modified.hour)}:${p(modified.minute)}',
              ),
              onTap: () => Navigator.pop(context, f),
            );
          }).toList(),
        ),
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: Text(
          'Toutes les données actuelles (transactions, catégories, '
          'supports, budgets) seront remplacées par le contenu de '
          '"${selected.uri.pathSegments.last}". Cette action est '
          'irréversible.',
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
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    String? passphrase;
    if (await BackupService.isEncrypted(selected)) {
      passphrase = await _askPassphrase(
        title: 'Sauvegarde chiffrée',
        helperText: 'Phrase de passe saisie à la création de ce fichier.',
      );
      if (passphrase == null || passphrase.isEmpty) return;
      if (!mounted) return;
    }

    try {
      await BackupService.restoreFromFile(selected, passphrase: passphrase);
    } on BackupPassphraseError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;
    await loadAccountData(context);
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppRoot()),
      (route) => false,
    );
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

    await TransactionsStore.clearAll();
    await ArchivesStore.clear();
    await MonthlyBalancesStore.clearAll();

    await ActiveMonthStore.set(_currentMonthKey());

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
    final containersStore = context.read<ContainersStore>();

    await TransactionsStore.clearAll();
    await ArchivesStore.clear();
    await CategoriesStore.clear();
    await containersStore.clearAll();
    await MonthlyBalancesStore.clearAll();
    await CategoryAllocationsStore.clearAll();
    await CategoryGoalsStore.clearAll();
    await RecurringTransactionsStore.clear();
    await ActiveMonthStore.clearAll();

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
            'Apparence',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Clair, sombre, ou personnalisé avec la couleur de votre choix '
            '(qui s\'adapte automatiquement au clair/sombre du système).',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<AppThemeChoice>(
            valueListenable: AppSettingsStore.themeChoiceNotifier,
            builder: (context, choice, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AppThemeChoice>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeChoice.light,
                        label: Text('Clair'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeChoice.dark,
                        label: Text('Sombre'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeChoice.custom,
                        label: Text('Personnalisé'),
                        icon: Icon(Icons.palette_outlined),
                      ),
                    ],
                    selected: {choice},
                    onSelectionChanged: (s) =>
                        AppSettingsStore.setThemeChoice(s.first),
                  ),
                  if (choice == AppThemeChoice.custom) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<Color?>(
                      valueListenable: AppSettingsStore.accentColorNotifier,
                      builder: (context, accentColor, _) {
                        final current =
                            accentColor ?? AppTheme.defaultSeedColor;
                        return Row(
                          children: [
                            const Text('Couleur d\'accent'),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showColorWheelPicker(
                                  context,
                                  initialColor: current,
                                );
                                if (picked != null) {
                                  AppSettingsStore.setAccentColor(picked);
                                }
                              },
                              child: CircleAvatar(backgroundColor: current),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Compte & sécurité',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Changer votre mot de passe ou l\'email utilisé pour vous '
            'connecter.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSecurityScreen(),
                ),
              );
            },
            icon: const Icon(Icons.lock_outline),
            label: const Text('Compte & sécurité'),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
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
          const Text(
            'Sauvegarde locale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Crée un fichier reprenant toutes vos données (transactions, '
            'catégories, supports, budgets) dans ~/StabilityBackups sur cet '
            'ordinateur. Rien n\'est envoyé en ligne.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.save_alt),
            label: const Text('Créer une sauvegarde'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickAndRestoreBackup,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer une sauvegarde'),
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
