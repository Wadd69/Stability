/// Enveloppe personnalisable pour la méthode "pourcentages personnalisés"
/// (généralisation de la règle 50/30/20 : au lieu de 3 enveloppes figées,
/// le compte définit N enveloppes avec un nom et un pourcentage au choix).
/// Stockée sur le compte cloud (voir CloudAccount.customBuckets).
class CustomBucket {
  final String id;
  final String name;

  /// Part du revenu prévisionnel visée par cette enveloppe (0.0 à 1.0).
  final double targetShare;

  const CustomBucket({
    required this.id,
    required this.name,
    required this.targetShare,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_share': targetShare,
      };

  factory CustomBucket.fromMap(Map<dynamic, dynamic> map) => CustomBucket(
        id: map['id'] as String,
        name: map['name'] as String,
        targetShare: (map['target_share'] as num).toDouble(),
      );
}

/// Enveloppes par défaut d'un compte fraîchement créé en mode "Règle
/// 50/30/20" — mêmes noms/pourcentages que l'ancienne version figée, pour
/// que l'expérience par défaut ne change pas. Modifiables ensuite depuis
/// l'écran de la méthode.
const List<CustomBucket> kDefaultBuckets = [
  CustomBucket(id: 'needs', name: 'Besoins', targetShare: 0.5),
  CustomBucket(id: 'wants', name: 'Envies', targetShare: 0.3),
  CustomBucket(id: 'savings', name: 'Épargne / dettes', targetShare: 0.2),
];
