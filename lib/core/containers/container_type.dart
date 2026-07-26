/// Type logique d’un conteneur financier.
/// Le type n’impose rien, il débloque des comportements futurs.
enum ContainerType {
  currentAccount,     // Compte courant
  savingsAccount,     // Épargne (LEP, Livret A, LDDS, etc.)
  investmentAccount,  // Investissement (PEA, CTO, etc.)
  insuranceLife,      // Assurance-vie
  retirementAccount,  // Retraite (PER, assimilé)
  cash,               // Espèces / liquide
  projectFund,        // Projet / fonds dédié
  other,              // Libre / personnalisé
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
    }
  }
}
