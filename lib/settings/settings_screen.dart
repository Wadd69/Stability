import 'package:flutter/material.dart';

import 'app_settings_store.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: AppSettingsStore.finnhubApiKey ?? '');
  }

  void _save() {
    AppSettingsStore.setFinnhubApiKey(_controller.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé enregistrée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.settings),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Actions / ETF',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pour suivre le cours d\'actions ou d\'ETF, il faut une clé API '
            'gratuite chez Finnhub (finnhub.io) : créez un compte gratuit, '
            'copiez votre clé personnelle et collez-la ici. Aucune carte '
            'bancaire n\'est demandée. La crypto, elle, ne demande aucune clé.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Clé API Finnhub',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}
