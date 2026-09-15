/// Type logique d’un conteneur financier.
/// Le type n’impose rien, il débloque des comportements futurs.
enum ContainerType {
  currentAccount, // Compte courant
  savingsAccount, // Épargne (LEP, Livret A, LDDS, etc.)
  investmentAccount, // Investissement (PEA, CTO, etc.)
  insuranceLife, // Assurance-vie
  retirementAccount, // Retraite (PER, assimilé)
  cash, // Espèces / liquide
  projectFund, // Projet / fonds dédié
  other, // Libre / personnalisé
  credit, // Crédit (immo, conso, revolving) — ajouté en dernier : l'index
  // est stocké tel quel côté Supabase, ne jamais réordonner cette liste.
}

/// Helpers d’affichage (UX)
extension ContainerTypeLabel on ContainerType {
  String get label {
    switch (this) {
      case ContainerType.currentAccount:
        return 'Compte courant';
      case ContainerType.savingsAccount:
        return 'Épargne';
      case ContainerType.investmentAccount:
        return 'Investissement';
      case ContainerType.insuranceLife:
        return 'Assurance-vie';
      case ContainerType.retirementAccount:
        return 'Retraite';
      case ContainerType.cash:
        return 'Espèces';
      case ContainerType.projectFund:
        return 'Projet / fonds';
      case ContainerType.other:
        return 'Autre';
      case ContainerType.credit:
        return 'Crédit';
    }
  }
}

/// Type de crédit — affecte seulement l'affichage/icône, le modèle de
/// calcul (mensualité saisie à la main, capital restant dû suivi
/// manuellement) est identique pour les trois.
enum CreditKind { immo, conso, revolving }

extension CreditKindLabel on CreditKind {
  String get label {
    switch (this) {
      case CreditKind.immo:
        return 'Crédit immobilier';
      case CreditKind.conso:
        return 'Crédit conso';
      case CreditKind.revolving:
        return 'Crédit revolving';
    }
  }
}
