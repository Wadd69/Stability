import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/auth_repository.dart';
import '../backend/cloud_account.dart';
import '../backend/cloud_accounts_repository.dart';
import 'current_account.dart';
import 'management_mode.dart';

/// Écran de création OU modification de compte. Utilisé comme première
/// page de l'app tant qu'aucun compte n'existe (voir AppRoot), et
/// réutilisable pour ajouter/modifier un compte depuis le sélecteur.
class CreateAccountScreen extends StatefulWidget {
  final VoidCallback? onCreated;
  final CloudAccount? existing;

  const CreateAccountScreen({super.key, this.onCreated, this.existing});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  late bool _isShared;
  late ManagementMode _mode;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _isShared = existing?.isShared ?? false;
    _mode = existing?.managementMode ?? ManagementMode.zeroBudget;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _performSave() async {
    if (widget.existing == null) {
      final account = await CloudAccountsRepository.createAccount(
        name: _nameController.text.trim(),
        isShared: _isShared,
        mode: _mode,
      );
      CurrentAccount.active = account;
    } else {
      final updated = CloudAccount(
        id: widget.existing!.id,
        name: _nameController.text.trim(),
        isShared: _isShared,
        managementMode: _mode,
        ownerId: widget.existing!.ownerId,
      );
      await CloudAccountsRepository.updateAccount(updated);
      if (CurrentAccount.active.id == updated.id) {
        CurrentAccount.active = updated;
      }
    }

    if (!mounted) return;

    if (widget.onCreated != null) {
      widget.onCreated!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _performSave();
    } catch (e) {
      // Diagnostic brut du tout premier échec, sans nouvelle tentative
      // intermédiaire (un rafraîchissement de session avant de réessayer
      // brouillait le diagnostic : il montrait l'état après coup, pas
      // celui qui a provoqué l'échec initial).
      String debugInfo = '';
      if (e.toString().contains('row-level security')) {
        final auth = Supabase.instance.client.auth;
        final session = auth.currentSession;
        final nowUtc = DateTime.now().toUtc();
        final expiresAt = session?.expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                session!.expiresAt! * 1000,
                isUtc: true,
              );
        final token = session?.accessToken;
        debugInfo = '\n[diag] uid=${auth.currentUser?.id} '
            'session=${session != null} '
            'expiresAt=$expiresAt now=$nowUtc '
            'expired=${expiresAt != null && expiresAt.isBefore(nowUtc)} '
            'tokenLen=${token?.length} tokenParts=${token?.split('.').length}';
      }

      if (!mounted) return;
      setState(() {
        _error = 'Erreur : ${e.toString()}$debugInfo';
        _saving = false;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthRepository.signOut();
    if (widget.onCreated != null) widget.onCreated!();
  }

  void _showModeComparison() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: ListView(
            controller: scrollController,
            children: [
              const Text(
                'Les méthodes de gestion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Pas sûr de quoi choisir ? Voici à quoi correspond chaque '
                'méthode. Vous pourrez en changer plus tard.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ...ManagementMode.values.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (m == _mode) ...[
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            m.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m.longDescription,
                          style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: widget.onCreated == null
          ? AppBar(
              title: Text(isEditing ? 'Modifier le compte' : 'Créer un compte'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onCreated != null && !isEditing) ...[
                    const Text(
                      'Bienvenue dans Stability',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Commençons par créer votre premier compte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nom du compte',
                      hintText: 'ex: Compte personnel',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compte partagé'),
                    subtitle: const Text('Couple, famille, colocation...'),
                    value: _isShared,
                    onChanged: (v) => setState(() => _isShared = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ManagementMode>(
                    initialValue: _mode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Méthode de gestion',
                      suffixIcon: IconButton(
                        tooltip: 'Comparer les méthodes',
                        icon: const Icon(Icons.info_outline),
                        onPressed: _showModeComparison,
                      ),
                    ),
                    items: ManagementMode.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Enregistrer' : 'Créer et continuer'),
                  ),
                  if (widget.onCreated != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : _signOut,
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
