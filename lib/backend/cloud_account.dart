import '../accounts/management_mode.dart';
import '../core/finance/budget_bucket.dart';

/// Compte tel que stocké côté Supabase (table `accounts`), visible
/// uniquement par ses membres (voir `account_members` + RLS).
class CloudAccount {
  final String id;
  final String name;
  final bool isShared;
  final ManagementMode managementMode;
  final String ownerId;

  /// Enveloppes de la méthode "pourcentages personnalisés" (mode
  /// fiftyThirtyTwenty — le nom du mode reste inchangé pour ne pas casser
  /// les comptes existants, mais les enveloppes sont maintenant
  /// configurables). Vide = utiliser [kDefaultBuckets], voir
  /// [effectiveBuckets].
  final List<CustomBucket> customBuckets;

  /// Part du revenu prévisionnel visée pour l'épargne "paie-toi en
  /// premier" (mode payYourselfFirst). Null tant que non configuré.
  final double? payYourselfFirstPercent;

  /// Support de destination de l'épargne "paie-toi en premier".
  final String? payYourselfFirstContainerId;

  const CloudAccount({
    required this.id,
    required this.name,
    required this.isShared,
    required this.managementMode,
    required this.ownerId,
    this.customBuckets = const [],
    this.payYourselfFirstPercent,
    this.payYourselfFirstContainerId,
  });

  List<CustomBucket> get effectiveBuckets =>
      customBuckets.isNotEmpty ? customBuckets : kDefaultBuckets;

  CloudAccount copyWith({
    String? name,
    bool? isShared,
    ManagementMode? managementMode,
    List<CustomBucket>? customBuckets,
    double? payYourselfFirstPercent,
    String? payYourselfFirstContainerId,
  }) {
    return CloudAccount(
      id: id,
      name: name ?? this.name,
      isShared: isShared ?? this.isShared,
      managementMode: managementMode ?? this.managementMode,
      ownerId: ownerId,
      customBuckets: customBuckets ?? this.customBuckets,
      payYourselfFirstPercent:
          payYourselfFirstPercent ?? this.payYourselfFirstPercent,
      payYourselfFirstContainerId:
          payYourselfFirstContainerId ?? this.payYourselfFirstContainerId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'is_shared': isShared,
      'management_mode': managementMode.name,
      'custom_buckets': customBuckets.map((e) => e.toMap()).toList(),
      'pay_yourself_first_percent': payYourselfFirstPercent,
      'pay_yourself_first_container_id': payYourselfFirstContainerId,
    };
  }

  factory CloudAccount.fromMap(Map<String, dynamic> map) {
    return CloudAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      isShared: map['is_shared'] as bool? ?? false,
      managementMode: ManagementMode.values.firstWhere(
        (e) => e.name == map['management_mode'],
        orElse: () => ManagementMode.free,
      ),
      ownerId: map['owner_id'] as String,
      customBuckets: (map['custom_buckets'] as List<dynamic>?)
              ?.map((e) => CustomBucket.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      payYourselfFirstPercent:
          (map['pay_yourself_first_percent'] as num?)?.toDouble(),
      payYourselfFirstContainerId:
          map['pay_yourself_first_container_id'] as String?,
    );
  }
}
