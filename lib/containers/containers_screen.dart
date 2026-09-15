import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/containers/containers_store.dart';
import '../core/containers/container_model.dart';
import '../core/containers/container_type.dart'; // ✅ AJOUT IMPORTANT
import 'edit_container_sheet.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../theme/app_colors.dart';

class ContainersScreen extends StatelessWidget {
  const ContainersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ContainersStore>();
    final containers = store.active;
    final archived = store.archived;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes & supports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.containers),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const EditContainerSheet(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: containers.isEmpty && archived.isEmpty
          ? const _EmptyState()
          : ListView(
              children: [
                for (final container in containers)
                  _ContainerTile(container: container),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    // Un support "Supprimer"-é une première fois est
                    // seulement archivé (voir ContainersStore.deleteContainer)
                    // — il faut pouvoir le retrouver ici pour le supprimer
                    // définitivement, sinon il reste invisible pour
                    // toujours sans qu'on puisse finir de le supprimer.
                    title: Text('Archivés (${archived.length})'),
                    children: [
                      for (final container in archived)
                        _ContainerTile(container: container, isArchived: true),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aucun support pour le moment.\n\n'
          'Crée ton premier compte ou support financier.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ContainerTile extends StatelessWidget {
  final ContainerModel container;
  final bool isArchived;

  const _ContainerTile({required this.container, this.isArchived = false});

  @override
  Widget build(BuildContext context) {
    final store = context.read<ContainersStore>();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: container.color,
      ),
      title: Text(container.name),
      subtitle: Text(container.type.label), // ✅ maintenant reconnu
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => EditContainerSheet(container: container),
            );
          }

          if (value == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  isArchived
                      ? 'Supprimer définitivement'
                      : 'Supprimer le support',
                ),
                content: Text(
                  isArchived
                      ? 'Le support "${container.name}" et son historique '
                          'seront définitivement supprimés. Cette action est '
                          'irréversible.'
                      : 'Le support "${container.name}" sera archivé (il '
                          'restera visible dans "Archivés" pour suppression '
                          'définitive).',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Supprimer',
                      style: TextStyle(color: context.appColors.negative),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await store.deleteContainer(container.id);
            }
          }
        },
        itemBuilder: (_) => [
          if (!isArchived)
            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
          PopupMenuItem(
            value: 'delete',
            child: Text(isArchived ? 'Supprimer définitivement' : 'Supprimer'),
          ),
        ],
      ),
    );
  }
}
