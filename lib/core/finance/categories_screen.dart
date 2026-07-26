import 'package:flutter/material.dart';
import 'categories_store.dart';
import 'budget_bucket.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';
import '../../accounts/current_account.dart';
import '../../accounts/management_mode.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const List<Color> _palette = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.brown,
    Colors.cyan,
  ];

  Widget _bucketChips({
    required BudgetBucket? selected,
    required ValueChanged<BudgetBucket?> onChanged,
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
          ...BudgetBucket.values.map((b) => ChoiceChip(
                label: Text(b.label),
                selected: selected == b,
                onSelected: (_) => onChanged(b),
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // ➕ AJOUT
  // ─────────────────────────────────
  void _addCategory() {
    final controller = TextEditingController();
    Color? selectedColor;
    BudgetBucket? selectedBucket;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Nouvelle catégorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _palette.map((c) {
                  final isSelected = selectedColor?.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: isSelected ? 3 : 1,
                          color: isSelected
                              ? Colors.black
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              _bucketChips(
                selected: selectedBucket,
                onChanged: (b) => setModalState(() => selectedBucket = b),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedColor == null
                  ? null
                  : () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        CategoriesStore.add(
                          name: name,
                          colorValue: selectedColor!.toARGB32(), // ✅ marche
                          bucket: selectedBucket,
                        );
                        setState(() {});
                      }
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
    Color selectedColor = Color(category.colorValue);
    BudgetBucket? selectedBucket = category.bucket;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Modifier la catégorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _palette.map((c) {
                  final isSelected = selectedColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: isSelected ? 3 : 1,
                          color: isSelected
                              ? Colors.black
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              _bucketChips(
                selected: selectedBucket,
                onChanged: (b) => setModalState(() => selectedBucket = b),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  CategoriesStore.update(
                    category.id,
                    newName: name, // ✅ marche (alias)
                    colorValue: selectedColor.toARGB32(), // ✅ marche
                    bucket: selectedBucket,
                    clearBucket: selectedBucket == null,
                  );
                  setState(() {});
                }
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
            onPressed: () {
              CategoriesStore.remove(category.id);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
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
                  builder: (_) =>
                      const HelpScreen(topic: HelpTopic.categories),
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
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = categories[index];

                final showBucket = CurrentAccount.active.managementMode ==
                        ManagementMode.fiftyThirtyTwenty &&
                    c.bucket != null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(c.colorValue),
                  ),
                  title: Text(c.name),
                  subtitle: showBucket ? Text(c.bucket!.label) : null,
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
