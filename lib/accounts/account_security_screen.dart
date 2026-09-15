import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/auth_repository.dart';
import '../accounts/current_account.dart';
import '../theme/app_colors.dart';

/// Changement du mot de passe, de l'email de connexion ou du nom
/// d'utilisateur (le compte d'authentification, pas un "compte"
/// Stability), et suppression définitive du compte. Chaque changement
/// est confirmé avant envoi : mot de passe saisi deux fois, email/
/// suppression confirmés par une boîte de dialogue.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>();

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _obscurePassword = true;
  bool _savingPassword = false;
  bool _savingEmail = false;
  bool _savingName = false;
  bool _deleting = false;
  String? _passwordError;
  String? _passwordSuccess;
  String? _emailError;
  String? _emailSuccess;
  String? _nameError;
  String? _nameSuccess;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _displayNameController.text = row?['display_name'] as String? ?? '';
      });
    } catch (_) {
      // Non bloquant : le champ reste vide, l'utilisateur peut quand même
      // en saisir un.
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _changeDisplayName() async {
    if (!_nameFormKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _savingName = true;
      _nameError = null;
      _nameSuccess = null;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        'display_name': _displayNameController.text.trim(),
      }).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _nameSuccess = 'Nom mis à jour.';
        _savingName = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nameError = 'Erreur : ${e.toString()}';
        _savingName = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Supprimer définitivement le compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est irréversible : votre connexion et vos '
                'données personnelles seront définitivement supprimées. '
                'Tapez SUPPRIMER pour confirmer.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'SUPPRIMER'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
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
              onPressed: controller.text.trim() == 'SUPPRIMER'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deleting = true);

    try {
      await AuthRepository.deleteOwnAccount();
      CurrentAccount.clear();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Échec de la suppression'),
          content: Text(
            '${e.toString()}\n\n'
            'La fonction "delete_own_account" doit être créée côté '
            'Supabase — voir l\'aide de cet écran pour le SQL à exécuter.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _savingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      if (!mounted) return;
      setState(() {
        _passwordSuccess = 'Mot de passe mis à jour.';
        _savingPassword = false;
      });
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _passwordError = 'Erreur : ${e.toString()}';
        _savingPassword = false;
      });
    }
  }

  Future<void> _changeEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final newEmail = _newEmailController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer le changement d\'email'),
        content: Text(
          'Votre email de connexion deviendra "$newEmail". '
          'Vous en aurez besoin pour vous reconnecter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _savingEmail = true;
      _emailError = null;
      _emailSuccess = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      if (!mounted) return;
      setState(() {
        _emailSuccess = 'Vérifiez votre nouvelle boîte mail (et les spams) '
            'pour confirmer le changement.';
        _savingEmail = false;
      });
      _newEmailController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emailError = 'Erreur : ${e.toString()}';
        _savingEmail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Compte & sécurité')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Email actuel : ${currentEmail ?? '—'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Text(
            'Nom d\'utilisateur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _nameFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Nom affiché'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nom requis'
                      : null,
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _nameError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_nameSuccess != null) ...[
                  const SizedBox(height: 12),
                  Text(_nameSuccess!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _savingName ? null : _changeDisplayName,
                    child: _savingName
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mettre à jour le nom'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Changer le mot de passe',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _passwordFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? '6 caractères minimum'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                  ),
                  validator: (v) => v != _newPasswordController.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _passwordError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_passwordSuccess != null) ...[
                  const SizedBox(height: 12),
                  Text(_passwordSuccess!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingPassword ? null : _changePassword,
                    child: _savingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mettre à jour le mot de passe'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Changer l\'email de connexion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _emailFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Nouvel email'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Email invalide' : null,
                ),
                if (_emailError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _emailError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_emailSuccess != null) ...[
                  const SizedBox(height: 12),
                  Text(_emailSuccess!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _savingEmail ? null : _changeEmail,
                    child: _savingEmail
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mettre à jour l\'email'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Zone de danger',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appColors.negative,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Supprime définitivement votre compte de connexion et vos '
            'données personnelles. Irréversible.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appColors.negative,
                side: BorderSide(color: context.appColors.negative),
              ),
              onPressed: _deleting ? null : _deleteAccount,
              child: _deleting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appColors.negative,
                      ),
                    )
                  : const Text('Supprimer mon compte'),
            ),
          ),
        ],
      ),
    );
  }
}
