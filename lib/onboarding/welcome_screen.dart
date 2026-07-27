import 'package:flutter/material.dart';

/// Première page jamais vue par un nouvel utilisateur, avant même la
/// connexion — présente l'app une seule fois (voir AppSettingsStore
/// .hasSeenWelcome), pas à chaque lancement.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.savings_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Bienvenue dans Stability',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Merci de nous faire confiance pour vous accompagner dans '
                'la gestion de votre argent.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Text(
                'Stability est pensée pour être pédagogique : que vous '
                'sachiez déjà gérer votre budget ou que vous débutiez, '
                'l\'app s\'adapte à votre façon de faire — suivi libre, '
                'budget base zéro, règle 50/30/20, et d\'autres méthodes '
                'à venir.',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Vos comptes peuvent être personnels ou partagés avec vos '
                'proches, avec une mise à jour en temps réel entre tous '
                'les appareils.',
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const Spacer(),
              const Spacer(),
              ElevatedButton(
                onPressed: onContinue,
                child: const Text('Commencer'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
