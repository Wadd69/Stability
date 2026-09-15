import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feedback_contact.dart';

/// Écran dédié aux retours des bêta-testeurs : bug, suggestion de
/// fonctionnalité, sondage mensuel. Chaque bouton ouvre le client mail du
/// téléphone avec un brouillon pré-rempli (destinataire, sujet, gabarit de
/// questions) adressé à [FeedbackContact.developerEmail] — le testeur n'a
/// plus qu'à compléter et appuyer sur envoyer depuis sa propre messagerie.
class BetaFeedbackScreen extends StatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  State<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends State<BetaFeedbackScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = '${info.version} (build ${info.buildNumber})';
    });
  }

  Future<void> _composeEmail({
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: FeedbackContact.developerEmail,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune app mail trouvée sur cet appareil')),
      );
    }
  }

  String get _versionLine => 'Version : ${_version ?? 'inconnue'}';

  void _sendBugReport() {
    _composeEmail(
      subject: 'Bug Stability',
      body: '$_versionLine\n\n'
          'Ce qui s\'est passé :\n\n\n'
          'Ce que j\'attendais :\n\n\n'
          'Étapes pour reproduire :\n\n',
    );
  }

  void _sendFeatureRequest() {
    _composeEmail(
      subject: 'Suggestion Stability',
      body: '$_versionLine\n\n'
          'Mon idée :\n\n',
    );
  }

  Widget _feedbackCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bêta & retours')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Merci de tester Stability ! Votre avis compte vraiment, '
            'surtout pendant cette phase de bêta — n\'hésitez pas à '
            'signaler ce qui bloque, même pour un détail. Chaque bouton '
            'ouvre votre app mail avec un message déjà préparé.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version installée : ${_version ?? '…'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _feedbackCard(
            icon: Icons.bug_report_outlined,
            title: 'Signaler un bug',
            description: 'Quelque chose ne fonctionne pas comme prévu ? '
                'Décrivez ce que vous avez fait et ce qui s\'est passé.',
            buttonLabel: 'Signaler un bug',
            onPressed: _sendBugReport,
          ),
          _feedbackCard(
            icon: Icons.lightbulb_outline,
            title: 'Proposer une fonctionnalité',
            description: 'Une idée pour améliorer l\'app, une fonctionnalité '
                'qui vous manque ? C\'est ici que ça se passe.',
            buttonLabel: 'Envoyer une requête',
            onPressed: _sendFeatureRequest,
          ),
        ],
      ),
    );
  }
}
