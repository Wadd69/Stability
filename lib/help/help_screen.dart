import 'package:flutter/material.dart';
import '../accounts/current_account.dart';
import '../accounts/management_mode.dart';
import 'help_topic.dart';

class HelpScreen extends StatelessWidget {
  final HelpTopic topic;

  const HelpScreen({
    super.key,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    final content = helpContents[topic]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Aide – ${content.title}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final paragraph in content.paragraphs) ...[
            Text(paragraph, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
          ],

          if (topic == HelpTopic.dashboard) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Mode de gestion du compte',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              CurrentAccount.active.managementMode.label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }
}
