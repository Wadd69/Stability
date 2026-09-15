import 'package:flutter/material.dart';

import '../backend/auth_repository.dart';
import '../backend/cloud_account.dart';
import '../backend/cloud_accounts_repository.dart';
import '../theme/app_colors.dart';
import 'current_account.dart';
import 'create_account_screen.dart';
import 'management_mode.dart';

class AccountSelectorScreen extends StatefulWidget {
  const AccountSelectorScreen({super.key});

  @override
  State<AccountSelectorScreen> createState() => _AccountSelectorScreenState();
}

class _AccountSelectorScreenState extends State<AccountSelectorScreen> {
  List<CloudAccount> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await CloudAccountsRepository.fetchMyAccounts();
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger vos comptes (pas de connexion ?)';
        _loading = false;
      });
    }
  }

  Future<void> _addAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
    _load();
  }

  Future<void> _editAccount(CloudAccount account) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(existing: account),
      ),
    );
    _load();
  }

  Future<void> _inviteToAccount(CloudAccount account) async {
    try {
      final code = await CloudAccountsRepository.createInvite(account.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Inviter sur "${account.name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Communiquez ce code à la personne à inviter :'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Elle pourra le saisir depuis "Rejoindre un compte" pour '
                'accéder à ce compte partagé.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de générer une invitation')),
      );
    }
  }

  Future<void> _manageMembers(CloudAccount account) async {
    List<Map<String, dynamic>> members = [];
    bool loading = true;
    String? error;

    Future<void> load(void Function(void Function()) setModalState) async {
      setModalState(() => loading = true);
      try {
        final result = await CloudAccountsRepository.fetchMembers(account.id);
        setModalState(() {
          members = result;
          loading = false;
          error = null;
        });
      } catch (e) {
        setModalState(() {
          loading = false;
          error = 'Impossible de charger les membres';
        });
      }
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          if (loading && members.isEmpty && error == null) {
            load(setModalState);
          }
          return AlertDialog(
            title: Text('Membres — ${account.name}'),
            content: SizedBox(
              width: double.maxFinite,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : error != null
                      ? Text(error!)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: members.map((m) {
                            final userId = m['id'] as String;
                            final email = m['email'] as String? ?? '';
                            final displayName =
                                (m['display_name'] as String?)?.trim();
                            final label =
                                (displayName != null && displayName.isNotEmpty)
                                    ? displayName
                                    : (email.isNotEmpty ? email : 'Membre');
                            final isSelf =
                                userId == AuthRepository.currentUser?.id;

                            return ListTile(
                              title: Text(label),
                              subtitle: email.isNotEmpty ? Text(email) : null,
                              trailing: isSelf
                                  ? const Text('Vous')
                                  : IconButton(
                                      tooltip: 'Retirer',
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                              'Retirer ce membre',
                                            ),
                                            content: Text(
                                              '"$label" perdra l\'accès au '
                                              'compte "${account.name}".',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: Text(
                                                  'Retirer',
                                                  style: TextStyle(
                                                    color: context
                                                        .appColors.negative,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true) return;
                                        try {
                                          await CloudAccountsRepository
                                              .removeMember(account.id, userId);
                                          await load(setModalState);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Impossible de retirer ce '
                                                'membre.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            );
                          }).toList(),
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _joinAccount() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejoindre un compte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'Code d\'invitation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    try {
      await CloudAccountsRepository.redeemInvite(code);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte rejoint avec succès')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide ou expiré')),
      );
    }
  }

  Future<void> _leaveOrDelete(CloudAccount account) async {
    final isOwner = account.ownerId == AuthRepository.currentUser?.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isOwner ? 'Supprimer le compte' : 'Quitter le compte'),
        content: Text(
          isOwner
              ? 'Ce compte sera supprimé pour tous ses membres.'
              : 'Vous perdrez l\'accès à "${account.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isOwner ? 'Supprimer' : 'Quitter',
              style: TextStyle(color: context.appColors.negative),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (isOwner) {
      await CloudAccountsRepository.deleteAccount(account.id);
    } else {
      await CloudAccountsRepository.leaveAccount(account.id);
    }

    final wasActive = account.id == CurrentAccount.active.id;
    await _load();

    // Le compte actif vient de disparaître : on bascule sur un autre
    // compte restant (ou on vide complètement l'actif s'il n'en reste
    // aucun) pour que le dashboard ne continue pas à afficher les
    // données d'un compte supprimé une fois cet écran refermé.
    if (wasActive) {
      if (_accounts.isNotEmpty) {
        CurrentAccount.active = _accounts.first;
      } else {
        CurrentAccount.clear();
      }
    }
  }

  Future<void> _signOut() async {
    await AuthRepository.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un compte'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: context.appColors.warning.withValues(alpha: 0.15),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      ..._accounts.map((account) {
                        final isActive = account.id == CurrentAccount.active.id;
                        final isOwner =
                            account.ownerId == AuthRepository.currentUser?.id;

                        return ListTile(
                          title: Text(account.name),
                          subtitle: Text(
                            '${account.managementMode.label}'
                            '${account.isShared ? ' · Partagé' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) const Icon(Icons.check),
                              if (account.isShared && isOwner) ...[
                                IconButton(
                                  tooltip: 'Inviter',
                                  icon: const Icon(Icons.person_add_alt),
                                  onPressed: () => _inviteToAccount(account),
                                ),
                                IconButton(
                                  tooltip: 'Gérer les membres',
                                  icon: const Icon(Icons.group_outlined),
                                  onPressed: () => _manageMembers(account),
                                ),
                              ],
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editAccount(account),
                              ),
                              IconButton(
                                tooltip: isOwner ? 'Supprimer' : 'Quitter',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _leaveOrDelete(account),
                              ),
                            ],
                          ),
                          onTap: () {
                            CurrentAccount.active = account;
                            Navigator.pop(context);
                          },
                        );
                      }),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.group_add),
                        title: const Text('Rejoindre un compte partagé'),
                        subtitle: const Text('Avec un code d\'invitation'),
                        onTap: _joinAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
