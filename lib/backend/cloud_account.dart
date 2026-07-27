import '../accounts/management_mode.dart';

/// Compte tel que stocké côté Supabase (table `accounts`), visible
/// uniquement par ses membres (voir `account_members` + RLS).
class CloudAccount {
  final String id;
  final String name;
  final bool isShared;
  final ManagementMode managementMode;
  final String ownerId;

  const CloudAccount({
    required this.id,
    required this.name,
    required this.isShared,
    required this.managementMode,
    required this.ownerId,
  });

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
    );
  }
}
