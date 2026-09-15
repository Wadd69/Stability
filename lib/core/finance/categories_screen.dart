import 'package:flutter/material.dart';
import 'categories_store.dart';
import 'active_month_store.dart';
import 'edit_recurring_transaction_sheet.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../accounts/current_account.dart';
import '../../accounts/management_mode.dart';
import '../../theme/app_colors.dart';
import '../../shared/color_wheel_picker.dart';
import '../budget_rules/category_allocations_store.dart';
import '../../equity/account_members_store.dart';
import '../../equity/split_rule.dart';
import '../../equity/split_rule_editor.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  Widget _colorPicker({
    required Color color,
    required ValueChanged<Color> onChanged,
  }) {
    return Row(
      children: [
        const Text('Couleur'),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showColorWheelPicker(
              context,
              initialColor: color,
            );
            if (picked != null) onChanged(picked);
          },
          child: CircleAvatar(backgroundColor: color),
        ),
      ],
    );
  }

  /// Ouvre la page d'aide "Rubriques", qui explique en détail le support de
  /// destination et le budget mensuel — le texte d'aide complet ne tient
  /// pas dans un helperText de champ sans être coupé.
  void _openCategoriesHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HelpScreen(topic: HelpTopic.categories),
      ),
    );
  }

  Widget _dialogTitle(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: Text(text)),
        IconButton(
          tooltip: 'Aide',
          icon: const Icon(Icons.help_outline),
          onPressed: _openCategoriesHelp,
        ),
      ],
    );
  }

  Widget _bucketChips({
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    if (CurrentAccount.active.managementMode !=
        ManagementMode.fiftyThirtyTwenty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Aucun'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          ...CurrentAccount.active.effectiveBuckets.map((b) => ChoiceChip(
                label: Text(
                    '${b.name} (${(b.targetShare * 100).toStringAsFixed(0)}%)'),
                selected: selected == b.id,
                onSelected: (_) => onChanged(b.id),
              )),
        ],
      ),
    );
  }

  /// Budget mensuel facultatif par rubrique, pour les modes qui n'ont pas
  /// déjà de mécanisme d'allocation dédié (budget base zéro : écran
  /// Budget ; 50/30/20 : enveloppes par bucket). Alimente l'alerte de
  /// dépassement du dashboard en mode "Suivi libre" / "Personnalisé".
  Widget _monthlyBudgetField(TextEditingController controller) {
    final mode = CurrentAccount.active.managementMode;
    if (mode != ManagementMode.free &&
        mode != ManagementMode.custom &&
        mode != ManagementMode.payYourselfFirst) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Budget mensuel (optionnel)',
          helperText: 'Alerte sur le dashboard si dépassé ce mois-ci.',
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // ➕ AJOUT
  // ─────────────────────────────────
  void _addCategory() {
    final controller = TextEditingController();
    final budgetController = TextEditingController();
    Color selectedColor = Colors.blue;
    String? selectedBucket;
    SplitRule? selectedSplitRule;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: _dialogTitle('Nouvelle catégorie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 16),
                _colorPicker(
                  color: selectedColor,
                  onChanged: (c) => setModalState(() => selectedColor = c),
                ),
                _bucketChips(
                  selected: selectedBucket,
                  onChanged: (b) => setModalState(() => selectedBucket = b),
                ),
                _monthlyBudgetField(budgetController),
                SplitRuleEditor(
                  initialValue: selectedSplitRule,
                  members: AccountMembersStore.all,
                  onChanged: (r) => selectedSplitRule = r,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newId =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  await CategoriesStore.add(
                    id: newId,
                    name: name,
                    colorValue: selectedColor.toARGB32(),
                    bucketId: selectedBucket,
                    splitRule: selectedSplitRule,
                  );
                  final budget = double.tryParse(
                    budgetController.text.trim().replaceAll(',', '.'),
                  );
                  if (budget != null && budget > 0) {
                    await CategoryAllocationsStore.setAllocated(
                      ActiveMonthStore.current,
                      newId,
                      budget,
                    );
                  }
                  if (mounted) setState(() {});
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // ✏️ ÉDITION
  // ─────────────────────────────────
  void _editCategory(Category category) {
    final controller = TextEditingController(text: category.name);
    final currentBudget = CategoryAllocationsStore.getAllocated(
      ActiveMonthStore.current,
      category.id,
    );
    final budgetController = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(2) : '',
    );
    Color selectedColor = Color(category.colorValue);
    String? selectedBucket = category.bucketId;
    SplitRule? selectedSplitRule = category.splitRule;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: _dialogTitle('Modifier la catégorie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                _colorPicker(
                  color: selectedColor,
                  onChanged: (c) => setModalState(() => selectedColor = c),
                ),
                _bucketChips(
                  selected: selectedBucket,
                  onChanged: (b) => setModalState(() => selectedBucket = b),
                ),
                _monthlyBudgetField(budgetController),
                SplitRuleEditor(
                  initialValue: selectedSplitRule,
                  members: AccountMembersStore.all,
                  onChanged: (r) => selectedSplitRule = r,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EditRecurringTransactionSheet(
                        initialCategoryId: category.id,
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Ajouter une transaction récurrente'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await CategoriesStore.update(
                    category.id,
                    newName: name, // ✅ marche (alias)
                    colorValue: selectedColor.toARGB32(), // ✅ marche
                    bucketId: selectedBucket,
                    clearBucket: selectedBucket == null,
                    splitRule: selectedSplitRule,
                    clearSplitRule: selectedSplitRule == null,
                  );
                  final budget = double.tryParse(
                        budgetController.text.trim().replaceAll(',', '.'),
                      ) ??
                      0;
                  await CategoryAllocationsStore.setAllocated(
                    ActiveMonthStore.current,
                    category.id,
                    budget,
                  );
                  if (mounted) setState(() {});
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // ❌ SUPPRESSION
  // ─────────────────────────────────
  void _deleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          'La catégorie "${category.name}" sera supprimée.\n\n'
          'Les transactions associées conserveront leur historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await CategoriesStore.remove(category.id);
              if (mounted) setState(() {});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text(
              'Supprimer',
              style: TextStyle(color: context.appColors.negative),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoriesStore.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les catégories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.categories),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'Aucune catégorie.\nAjoutez-en une avec le bouton +.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = categories[index];

                String? bucketName;
                for (final b in CurrentAccount.active.effectiveBuckets) {
                  if (b.id == c.bucketId) {
                    bucketName = b.name;
                    break;
                  }
                }
                final showBucket = CurrentAccount.active.managementMode ==
                        ManagementMode.fiftyThirtyTwenty &&
                    bucketName != null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(c.colorValue),
                  ),
                  title: Text(c.name),
                  subtitle: showBucket ? Text(bucketName) : null,
                  onTap: () => _editCategory(c),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteCategory(c),
                  ),
                );
              },
            ),
    );
  }
}
