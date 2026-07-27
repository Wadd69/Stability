/// Un sujet d'aide contextuelle : une entrée par écran de l'app.
/// Pour ajouter l'aide sur un nouvel écran : ajouter une valeur ici,
/// son contenu dans [helpContents], puis un bouton "?" dans l'écran
/// qui ouvre `HelpScreen(topic: HelpTopic.xxx)`.
enum HelpTopic {
  dashboard,
  netWorth,
  transactionsList,
  budget,
  fiftyThirtyTwenty,
  categories,
  recurringTransactions,
  containers,
  savingsInterests,
  insuranceLife,
  retirement,
  investment,
  archives,
  archiveDetail,
  globalHistory,
  monthRecap,
  comparison,
  settings,
}

class HelpContent {
  final String title;
  final List<String> paragraphs;

  const HelpContent({
    required this.title,
    required this.paragraphs,
  });
}

const Map<HelpTopic, HelpContent> helpContents = {
  HelpTopic.dashboard: HelpContent(
    title: 'Tableau de bord',
    paragraphs: [
      'C\'est votre écran principal : le solde du mois actif, la liste de '
          'vos supports (comptes, épargne, etc.) et leurs mouvements.',
      'Le bouton ⊕ en bas permet d\'ajouter une entrée, une sortie ou un '
          'transfert entre deux supports.',
      'Taper sur une transaction l\'ouvre en modification ; la glisser vers '
          'la gauche la supprime. Un appui long sur une transaction d\'un '
          'compte courant la marque comme "pointée" (confirmée en banque).',
      'Depuis le formulaire d\'ajout, "Diviser sur plusieurs catégories" '
          'permet de répartir une même dépense (ex: un ticket de caisse) '
          'sur plusieurs catégories à la fois — repérables par l\'icône '
          '✂️ à côté de leur nom.',
      'La flèche double (⏭) clôture le mois actif : les opérations pointées '
          'sont archivées, les autres passent au mois suivant sans impacter '
          'le solde.',
    ],
  ),
  HelpTopic.netWorth: HelpContent(
    title: 'Patrimoine',
    paragraphs: [
      'Vue d\'ensemble de tout ce que vous possédez, tous supports '
          'confondus : comptes, épargne, assurance-vie, retraite et '
          'investissement.',
      'Le total est exprimé en euros uniquement. Les actions/ETF cotées '
          'en dollars sont affichées séparément, jamais additionnées au '
          'total euro pour éviter un chiffre faux sans conversion de '
          'change.',
      'Les valeurs assurance-vie/retraite/épargne sont calculées comme '
          'sur leurs écrans dédiés. Les cours crypto/actions se '
          'rafraîchissent avec le bouton en haut à droite.',
    ],
  ),
  HelpTopic.transactionsList: HelpContent(
    title: 'Transactions',
    paragraphs: [
      'Vue globale de toutes vos transactions, tous supports et tous mois '
          'confondus — contrairement au dashboard qui ne montre que le mois '
          'actif, réparti par support.',
      'La recherche filtre par libellé. L\'icône entonnoir ouvre les '
          'filtres : type, support, catégorie, période.',
      'Comme sur le dashboard : taper une ligne l\'ouvre en modification, '
          'la glisser vers la gauche la supprime (les deux côtés d\'un '
          'transfert ou d\'un split partent ensemble).',
    ],
  ),
  HelpTopic.budget: HelpContent(
    title: 'Budget base zéro',
    paragraphs: [
      'Le principe du budget base zéro : chaque euro de revenu doit être '
          'affecté à une catégorie, jusqu\'à ce que le "reste à allouer" '
          'atteigne 0.',
      'Commencez par définir le revenu prévisionnel du mois (bouton en '
          'haut), puis répartissez-le en tapant sur chaque catégorie pour '
          'lui donner un montant alloué.',
      'Le montant "restant" d\'une catégorie (alloué + reporté − dépensé) '
          'passe en rouge en cas de dépassement.',
      'Ce qui n\'est pas dépensé dans une catégorie se reporte '
          'automatiquement sur le mois suivant à la clôture du mois.',
      'Le drapeau à côté d\'une catégorie permet de lui donner un objectif '
          'd\'épargne (ex: 600€ pour des vacances) : la barre de progression '
          'suit le solde reporté au fil des mois, sans rien changer à votre '
          'façon d\'allouer le budget.',
    ],
  ),
  HelpTopic.fiftyThirtyTwenty: HelpContent(
    title: 'Règle 50 / 30 / 20',
    paragraphs: [
      'Cette méthode répartit votre revenu en trois enveloppes : 50% pour '
          'les besoins essentiels (loyer, courses, factures), 30% pour les '
          'envies (loisirs, sorties), 20% pour l\'épargne ou le remboursement '
          'de dettes.',
      'Chaque catégorie doit être classée dans l\'une des trois enveloppes '
          '(écran Catégories) pour que ses dépenses comptent dans le bon '
          'objectif.',
      'La barre devient rouge quand une enveloppe dépasse son objectif — '
          'contrairement au budget base zéro, il n\'y a pas d\'allocation '
          'précise par catégorie, seulement ces trois grands objectifs.',
      'Ce mode est actif uniquement pour les comptes configurés en "Règle '
          '50/30/20" (voir le sélecteur de compte).',
    ],
  ),
  HelpTopic.categories: HelpContent(
    title: 'Catégories',
    paragraphs: [
      'Les catégories permettent de classer vos entrées et sorties '
          '(alimentation, loisirs, salaire...) et servent de base au '
          'budget base zéro.',
      'Chaque catégorie a un nom et une couleur, utilisés partout dans '
          'l\'app (dashboard, budget, graphiques).',
      'Supprimer une catégorie n\'efface pas l\'historique des '
          'transactions déjà classées avec : elles gardent leur trace.',
      'En mode "Règle 50/30/20", chaque catégorie peut aussi être classée '
          'en besoins, envies ou épargne, pour alimenter les objectifs de '
          'cette méthode.',
    ],
  ),
  HelpTopic.recurringTransactions: HelpContent(
    title: 'Transactions récurrentes',
    paragraphs: [
      'Définissez ici les mouvements qui reviennent régulièrement (loyer, '
          'salaire, abonnements) : ils se créent automatiquement, sans que '
          'vous ayez à les ressaisir chaque mois.',
      'La génération se fait à la clôture du mois (ou immédiatement si '
          'vous créez une récurrence déjà due pour le mois en cours).',
      'Le bouton bascule (on/off) permet de mettre une récurrence en pause '
          'sans la supprimer. La supprimer n\'efface pas les transactions '
          'déjà créées, seulement les futures générations.',
      'Modifier le montant ou le libellé d\'une récurrence ne change que '
          'les prochaines transactions générées, jamais l\'historique.',
    ],
  ),
  HelpTopic.containers: HelpContent(
    title: 'Supports',
    paragraphs: [
      'Un support représente un endroit où se trouve votre argent : '
          'compte courant, épargne, espèces, projet/fonds dédié, '
          'assurance-vie, retraite (PER) ou investissement.',
      'Le compte courant suit un cycle mensuel (comme un chéquier) : ses '
          'mouvements sont archivés à la clôture du mois.',
      'Épargne, espèces et projet/fonds sont des réserves permanentes : '
          'leur contenu reste visible et accessible quel que soit le mois '
          'actif.',
      'Assurance-vie, retraite et investissement ouvrent directement un '
          'écran dédié au tap, même sans argent dessus encore.',
    ],
  ),
  HelpTopic.savingsInterests: HelpContent(
    title: 'Intérêts d\'épargne',
    paragraphs: [
      'Cet écran calcule les intérêts de votre épargne selon la méthode '
          'réelle des quinzaines (comme un Livret A) : le capital présent '
          'au 1er ou au 16 du mois rapporte au taux annuel ÷ 24.',
      'Le calcul se base sur tout l\'historique des versements de ce '
          'support, jusqu\'à la fin du mois actif de l\'app.',
      'Vous pouvez corriger manuellement un intérêt calculé (icône crayon) '
          'si le relevé bancaire réel diffère légèrement.',
      'Le bouton "Ajouter les intérêts au solde" transforme les lignes '
          'calculées en vraies transactions, qui viendront ensuite '
          'augmenter le capital pris en compte pour les quinzaines '
          'suivantes.',
    ],
  ),
  HelpTopic.insuranceLife: HelpContent(
    title: 'Assurance-vie',
    paragraphs: [
      'Un contrat d\'assurance-vie en fonds euros capitalise ses intérêts '
          'une fois par an : une fois inscrits, ils sont définitivement '
          'acquis et rapportent eux-mêmes l\'année suivante (l\'"effet '
          'cliquet"). C\'est le mode "Intérêt plein".',
      'Le mode "Prorata temporis" donne une estimation journalière de la '
          'valeur entre deux inscriptions officielles.',
      'Utilisez les boutons "Versement" / "Rachat" pour enregistrer un '
          'mouvement sur ce contrat.',
      'La "valeur corrigée" écrase le calcul automatique si votre relevé '
          'réel indique un montant différent.',
    ],
  ),
  HelpTopic.retirement: HelpContent(
    title: 'Retraite (PER)',
    paragraphs: [
      'Un Plan Épargne Retraite fonctionne comme un contrat d\'assurance-vie '
          '(mêmes modes de capitalisation), mais l\'argent est bloqué '
          'jusqu\'à la retraite.',
      'Six cas permettent un déblocage anticipé légal : achat de la '
          'résidence principale, invalidité, décès du conjoint, fin de '
          'droits au chômage, surendettement, cessation d\'activité non '
          'salariée.',
      'Le bandeau en haut de l\'écran indique si l\'épargne est encore '
          'bloquée ou déjà disponible selon la date de déblocage que vous '
          'avez renseignée.',
    ],
  ),
  HelpTopic.investment: HelpContent(
    title: 'Investissement',
    paragraphs: [
      'Cet écran suit la valeur de vos positions en crypto et en actions/ETF '
          'à partir de cours de marché récupérés en ligne.',
      'La crypto est gratuite et sans configuration (cours en euros via '
          'CoinGecko). Les actions/ETF nécessitent une clé API gratuite '
          '(Finnhub), à renseigner dans Réglages — cours affichés en '
          'dollars.',
      'Les deux totaux ne sont volontairement pas additionnés : ce sont '
          'deux devises différentes (€ / \$), les mélanger donnerait un '
          'chiffre faux.',
      'Le bouton de rafraîchissement récupère les derniers cours ; en cas '
          'de coupure réseau, le dernier prix connu reste affiché.',
    ],
  ),
  HelpTopic.archives: HelpContent(
    title: 'Archives',
    paragraphs: [
      'Les mois clôturés sont conservés ici, classés par année, avec '
          'leurs totaux et leur solde de clôture.',
      'La "Vue globale" cumule tout l\'historique et répartit les dépenses '
          'par catégorie depuis le début.',
      'Le bouton "Comparer" permet de mettre plusieurs périodes côte à '
          'côte (courbes, répartition, tableau).',
    ],
  ),
  HelpTopic.archiveDetail: HelpContent(
    title: 'Analyse d\'une période archivée',
    paragraphs: [
      'Le camembert intérieur répartit les dépenses par catégorie. Tapez '
          'une part pour voir le détail des transactions de cette '
          'catégorie ; le bouton "Retour catégories" revient à la vue '
          'd\'ensemble.',
      'Le bouton %/€ en haut à droite bascule l\'affichage entre montant '
          'et pourcentage.',
      'Ces chiffres sont figés au moment de la clôture du mois : ils ne '
          'changent plus, contrairement au récap du mois en cours.',
    ],
  ),
  HelpTopic.globalHistory: HelpContent(
    title: 'Historique global',
    paragraphs: [
      'Vue cumulée de tous les mois archivés depuis le début, sans limite '
          'de période.',
      'Les icônes en haut affichent ou masquent la courbe d\'évolution et '
          'le camembert de répartition, indépendamment l\'un de l\'autre.',
      'Comme sur les autres écrans d\'analyse, tapez une catégorie du '
          'camembert pour voir son détail.',
    ],
  ),
  HelpTopic.monthRecap: HelpContent(
    title: 'Récap du mois',
    paragraphs: [
      'Vue synthétique des dépenses du mois actif, sous forme de '
          'camembert par catégorie.',
      'Les transactions reportées d\'un mois précédent (non pointées) sont '
          'exclues de cette analyse pour ne pas fausser la répartition.',
    ],
  ),
  HelpTopic.comparison: HelpContent(
    title: 'Comparaison',
    paragraphs: [
      'Comparez plusieurs mois ou années entre eux : courbe d\'évolution, '
          'répartition par catégorie, ou tableau chiffré.',
      'Utile pour repérer une tendance (une catégorie qui dérive dans le '
          'temps) plutôt que de regarder un seul mois isolément.',
    ],
  ),
  HelpTopic.settings: HelpContent(
    title: 'Réglages',
    paragraphs: [
      'Configurez ici la clé API Finnhub nécessaire au suivi des actions '
          'et ETF (gratuite, sans carte bancaire — voir finnhub.io).',
      'Sans clé configurée, le suivi crypto reste utilisable normalement : '
          'seule la partie actions/ETF en a besoin.',
    ],
  ),
};
