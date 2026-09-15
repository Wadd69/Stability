import 'package:flutter/material.dart';

class _TutorialPage {
  final IconData icon;
  final String title;
  final String body;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const _pages = [
  _TutorialPage(
    icon: Icons.account_balance,
    title: 'Vos supports',
    body: 'Vous venez de créer votre premier support. Ajoutez-en '
        'd\'autres avec ce même bouton "+" — épargne, espèces, projet, '
        'assurance-vie... Un seul compte courant peut être "principal", '
        'c\'est celui dont le solde s\'affiche sur le dashboard.',
  ),
  _TutorialPage(
    icon: Icons.category,
    title: 'Les catégories',
    body: 'Icône en forme de losanges dans la barre du bas. Les '
        'catégories classent vos entrées et sorties (Alimentation, '
        'Loisirs, Salaire...). Chacune a une couleur, et peut avoir un '
        'budget mensuel facultatif.',
  ),
  _TutorialPage(
    icon: Icons.add_circle,
    title: 'Ajouter une opération',
    body: 'Le "+" au centre de la barre du bas : entrée, sortie ou '
        'transfert entre supports. Une opération peut être divisée sur '
        'plusieurs catégories ou plusieurs supports à la fois.',
  ),
  _TutorialPage(
    icon: Icons.event_repeat,
    title: 'Transactions récurrentes',
    body: 'Loyer, salaire, abonnement, remboursement de crédit... tout '
        'mouvement qui revient chaque mois se configure une fois ici et '
        'se crée ensuite tout seul, sans ressaisie.',
  ),
  _TutorialPage(
    icon: Icons.pie_chart,
    title: 'Analyser vos finances',
    body: 'Le camembert donne le récap du mois. Le tiroir latéral '
        '(icône ☰ en haut à gauche) ouvre aussi Archives et Comparaison '
        'pour suivre vos tendances sur plusieurs mois.',
  ),
  _TutorialPage(
    icon: Icons.dashboard_customize,
    title: 'Le dashboard',
    body: 'Depuis le tiroir latéral, "Personnaliser le dashboard" vous '
        'laisse choisir quels blocs et quels supports afficher — rien '
        'n\'est figé, adaptez-le à votre usage.',
  ),
];

/// Mini-tuto affiché une seule fois, juste après la création du premier
/// support d'un compte — présente les boutons principaux plutôt que de
/// laisser l'utilisateur les découvrir seul.
class DashboardTutorialScreen extends StatefulWidget {
  const DashboardTutorialScreen({super.key});

  @override
  State<DashboardTutorialScreen> createState() =>
      _DashboardTutorialScreenState();
}

class _DashboardTutorialScreenState extends State<DashboardTutorialScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      Navigator.pop(context);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Passer'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 64, color: colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _index == _pages.length - 1 ? 'Terminer' : 'Suivant',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
