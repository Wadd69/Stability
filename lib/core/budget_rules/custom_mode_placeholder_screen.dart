import 'package:flutter/material.dart';

class CustomModePlaceholderScreen extends StatelessWidget {
  const CustomModePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode personnalisé')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Le mode de gestion personnalisé n\'est pas encore disponible.\n\n'
            'En attendant, vos transactions restent suivies normalement '
            'sur le dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
