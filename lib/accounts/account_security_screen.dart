import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Changement du mot de passe ou de l'email de connexion (le compte
/// d'authentification, pas un "compte" Stability). Chaque changement est
/// confirmé avant envoi : mot de passe saisi deux fois, email confirmé par
/// une boîte de dialogue.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();

  bool _obscurePassword = true;
  bool _savingPassword = false;
  bool _savingEmail = false;
  String? _passwordError;
  String? _passwordSuccess;
  String? _emailError;
  String? _emailSuccess;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
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
        ],
      ),
    );
  }
}
