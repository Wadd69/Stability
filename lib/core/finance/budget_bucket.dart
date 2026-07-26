/// Classement d'une catégorie pour la méthode 50/30/20 :
/// 50% besoins essentiels, 30% envies/loisirs, 20% épargne/dettes.
/// Non utilisé en mode "budget base zéro" ou "suivi libre".
enum BudgetBucket { needs, wants, savings }

extension BudgetBucketLabel on BudgetBucket {
  String get label {
    switch (this) {
      case BudgetBucket.needs:
        return 'Besoins (50%)';
      case BudgetBucket.wants:
        return 'Envies (30%)';
      case BudgetBucket.savings:
        return 'Épargne / dettes (20%)';
    }
  }

  double get targetShare {
    switch (this) {
      case BudgetBucket.needs:
        return 0.5;
      case BudgetBucket.wants:
        return 0.3;
      case BudgetBucket.savings:
        return 0.2;
    }
  }
}
