enum ManagementMode {
  free, // suivi simple
  zeroBudget, // budget base zéro
  fiftyThirtyTwenty, // pourcentages personnalisés (anciennement 50/30/20 figé)
  payYourselfFirst, // paie-toi en premier
  custom,
}

extension ManagementModeLabel on ManagementMode {
  String get label {
    switch (this) {
      case ManagementMode.free:
        return 'Suivi libre';
      case ManagementMode.zeroBudget:
        return 'Budget base zéro';
      case ManagementMode.fiftyThirtyTwenty:
        return 'Pourcentages personnalisés';
      case ManagementMode.payYourselfFirst:
        return 'Paie-toi en premier';
      case ManagementMode.custom:
        return 'Personnalisé';
    }
  }

  String get description {
    switch (this) {
      case ManagementMode.free:
        return 'Suivi simple des entrées/sorties, sans contrainte de budget.';
      case ManagementMode.zeroBudget:
        return 'Chaque euro de revenu est alloué à une catégorie jusqu\'à '
            'ce qu\'il ne reste rien à répartir.';
      case ManagementMode.fiftyThirtyTwenty:
        return 'Répartissez votre revenu en enveloppes à vos propres '
            'pourcentages (ex: 50/30/20, ou tout autre découpage).';
      case ManagementMode.payYourselfFirst:
        return 'Un pourcentage de votre revenu part en épargne en premier, '
            'le reste est libre.';
      case ManagementMode.custom:
        return 'Méthode personnalisée (pas encore disponible).';
    }
  }

  /// Explication complète, pour les personnes qui découvrent la méthode.
  String get longDescription {
    switch (this) {
      case ManagementMode.free:
        return 'Vous suivez vos entrées et sorties d\'argent sans '
            'contrainte de budget imposée. Idéal si vous voulez juste '
            'garder un œil sur vos comptes sans méthode particulière, ou '
            'si vous découvrez l\'app et préférez commencer simple.';
      case ManagementMode.zeroBudget:
        return 'Chaque euro de revenu reçoit une mission précise : vous '
            'répartissez tout votre revenu du mois entre vos catégories '
            'de dépenses jusqu\'à ce qu\'il ne reste plus rien à allouer. '
            'Cette méthode force à anticiper chaque dépense à l\'avance '
            'plutôt que de constater après coup où l\'argent est parti.';
      case ManagementMode.fiftyThirtyTwenty:
        return 'Vous définissez vos propres enveloppes (nom et '
            'pourcentage du revenu) — par exemple 50% besoins essentiels, '
            '30% envies, 20% épargne, ou tout autre découpage qui vous '
            'convient. Moins précis que le budget base zéro, mais plus '
            'rapide à mettre en place, et modifiable à tout moment.';
      case ManagementMode.payYourselfFirst:
        return 'Dès que le revenu du mois est connu, un pourcentage fixe '
            'part automatiquement en épargne — avant toute autre dépense. '
            'Le reste de l\'argent est géré librement, sans suivi détaillé '
            'poste par poste. Un bon compromis entre "Suivi libre" (aucune '
            'structure) et "Budget base zéro" (structure complète).';
      case ManagementMode.custom:
        return 'Cette méthode n\'est pas encore disponible. Elle vous '
            'permettra plus tard de définir vos propres règles de '
            'gestion sur mesure.';
    }
  }
}
