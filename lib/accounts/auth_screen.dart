import 'package:flutter/material.dart';

import '../backend/auth_repository.dart';
import '../backend/supabase_config.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isSignUp) {
        await AuthRepository.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        if (!AuthRepository.isAuthenticated) {
          // Confirmation email activée sur le projet Supabase.
          setState(() {
            _info = 'Compte créé. Vérifiez votre boîte mail (et vos spams) '
                'pour confirmer votre adresse avant de vous connecter. '
                'D\'autres mails suivront pendant la bêta — ils sont '
                'importants pour la suite de l\'app.';
            _loading = false;
          });
          return;
        }
      } else {
        await AuthRepository.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      widget.onAuthenticated();
    } catch (e) {
      setState(() {
        _error = 'Échec : ${e.toString()}';
        _loading = false;
      });
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: 'On vous envoie un lien pour choisir un nouveau '
                'mot de passe.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !email.contains('@')) return;
    if (!mounted) return;

    try {
      await AuthRepository.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.passwordResetRedirectUrl,
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _info = 'Si un compte existe avec cet email, un lien de '
            'réinitialisation vient d\'être envoyé (pensez à vérifier vos '
            'spams).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Échec : ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Text(
                    'Stability',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Créer un compte' : 'Se connecter',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email invalide'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
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
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_info != null) ...[
                    Text(_info!),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Créer mon compte' : 'Connexion'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                              _info = null;
                            }),
                    child: Text(
                      _isSignUp
                          ? 'Déjà un compte ? Se connecter'
                          : 'Pas encore de compte ? En créer un',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
