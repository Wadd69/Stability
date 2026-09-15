import 'package:flutter/material.dart';

import '../backend/auth_repository.dart';
import '../core/finance/active_month_store.dart';
import '../core/finance/categories_store.dart';
import '../theme/app_colors.dart';
import 'account_member.dart';
import 'account_members_store.dart';
import 'equity_settlement_service.dart';
import 'split_rule.dart';
import 'split_rule_editor.dart';

const _kMonthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String _monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  final month = int.parse(parts[1]);
  return '${_kMonthNames[month - 1]} ${parts[0]}';
}

/// Écran "Équité" d'un compte partagé : revenus déclarés par chaque
/// membre, règles de répartition des dépenses par rubrique, et solde du
/// mois (qui doit rembourser combien à qui).
class EquityHubScreen extends StatefulWidget {
  const EquityHubScreen({super.key});

  @override
  State<EquityHubScreen> createState() => _EquityHubScreenState();
}

class _EquityHubScreenState extends State<EquityHubScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AccountMembersStore.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _editMyIncome(AccountMember me) async {
    final controller = TextEditingController(
      text: me.monthlyIncome > 0 ? me.monthlyIncome.toStringAsFixed(2) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mon revenu mensuel'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Revenu net / mois €'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, v ?? 0);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      await AccountMembersStore.setMyIncome(result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editCategoryRule(Category category) async {
    SplitRule? selected = category.splitRule;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Répartition — ${category.name}'),
          content: SingleChildScrollView(
            child: SplitRuleEditor(
              initialValue: selected,
              members: AccountMembersStore.all,
              onChanged: (r) => selected = r,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                await CategoriesStore.update(
                  category.id,
                  splitRule: selected,
                  clearSplitRule: selected == null,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _ruleLabel(SplitRule? rule) {
    if (rule == null) return SplitMode.proportional.label;
    if (rule.mode == SplitMode.assigned) {
      final member = AccountMembersStore.getById(rule.assignedUserId ?? '');
      return '${SplitMode.assigned.label} (${member?.displayName ?? '?'})';
    }
    return rule.mode.label;
  }

  Widget _incomesSection(List<AccountMember> members) {
    final myId = AuthRepository.currentUser?.id;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenus déclarés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sert de base à la répartition "proportionnelle aux revenus".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final m in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.displayName),
                trailing: Text(
                  '${m.monthlyIncome.toStringAsFixed(0)} €/mois',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: m.userId == myId ? () => _editMyIncome(m) : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _rulesSection() {
    final categories = CategoriesStore.all;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par rubrique',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Par défaut, une dépense est répartie au prorata des revenus. '
              'Une transaction récurrente peut avoir sa propre règle '
              '(voir son éditeur).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty)
              const Text('Aucune rubrique.')
            else
              for (final c in categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: Color(c.colorValue)),
                  title: Text(c.name),
                  subtitle: Text(_ruleLabel(c.splitRule)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editCategoryRule(c),
                ),
          ],
        ),
      ),
    );
  }

  Widget _settlementSection() {
    final monthKey = ActiveMonthStore.current;
    final result = EquitySettlementService.computeForMonth(monthKey);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solde — ${_monthLabel(monthKey)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final s in result.members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.member.displayName)),
                    Text(
                      'Payé ${s.paid.toStringAsFixed(0)} € · '
                      'Dû ${s.due.toStringAsFixed(0)} €',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.balance >= 0 ? '+' : ''}${s.balance.toStringAsFixed(0)} €',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: s.balance >= 0
                            ? context.appColors.positive
                            : context.appColors.negative,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            if (result.transfers.isEmpty)
              const Text('Tout le monde est à jour, rien à rembourser.')
            else
              for (final t in result.transfers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${t.from.displayName} doit verser '
                    '${t.amount.toStringAsFixed(2)} € à ${t.to.displayName}',
                  ),
                ),
            if (result.totalUnassigned > 0.01) ...[
              const SizedBox(height: 8),
              Text(
                '${result.totalUnassigned.toStringAsFixed(0)} € de dépenses '
                'sans "payé par" renseigné — le solde ci-dessus est '
                'incomplet.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Équité')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final members = AccountMembersStore.all;
              if (members.length < 2) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ce compte n\'a qu\'un seul membre pour l\'instant — '
                      'invitez quelqu\'un depuis le sélecteur de comptes '
                      'pour activer le partage équitable.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _incomesSection(members),
                  const SizedBox(height: 16),
                  _rulesSection(),
                  const SizedBox(height: 16),
                  _settlementSection(),
                ],
              );
            }),
    );
  }
}
