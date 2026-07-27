enum ManagementMode {
  free,        // suivi simple
  zeroBudget,  // budget base zéro
  fiftyThirtyTwenty,
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
        return 'Règle 50 / 30 / 20';
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
        return '50% besoins essentiels, 30% envies, 20% épargne/dettes.';
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
        return 'Une règle simple pour démarrer sans passer par une '
            'planification détaillée : 50% de votre revenu pour les '
            'besoins essentiels (loyer, courses, factures), 30% pour les '
            'envies (loisirs, sorties), et 20% pour l\'épargne ou le '
            'remboursement de dettes. Moins précis que le budget base '
            'zéro, mais plus rapide à mettre en place.';
      case ManagementMode.custom:
        return 'Cette méthode n\'est pas encore disponible. Elle vous '
            'permettra plus tard de définir vos propres règles de '
            'gestion sur mesure.';
    }
  }
}
