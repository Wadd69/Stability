import 'package:supabase_flutter/supabase_flutter.dart';

import '../accounts/management_mode.dart';
import 'cloud_account.dart';

/// CRUD des comptes partagés côté Supabase. La sécurité réelle est
/// appliquée par les règles RLS définies en base — ce dépôt ne fait
/// qu'exposer des appels réseau simples.
class CloudAccountsRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<CloudAccount>> fetchMyAccounts() async {
    final rows = await _client.from('accounts').select();
    return (rows as List)
        .map((r) => CloudAccount.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<CloudAccount> createAccount({
    required String name,
    required bool isShared,
    required ManagementMode mode,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('accounts')
        .insert({
          'name': name,
          'is_shared': isShared,
          'management_mode': mode.name,
          'owner_id': userId,
        })
        .select()
        .single();
    return CloudAccount.fromMap(row);
  }

  static Future<void> updateAccount(CloudAccount account) async {
    await _client.from('accounts').update(account.toMap()).eq('id', account.id);
  }

  static Future<void> deleteAccount(String id) async {
    await _client.from('accounts').delete().eq('id', id);
  }

  /// Quitte un compte partagé (sans le supprimer pour les autres membres).
  static Future<void> leaveAccount(String accountId) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('account_members')
        .delete()
        .eq('account_id', accountId)
        .eq('user_id', userId);
  }

  /// Génère un code d'invitation à partager (lien ou QR code côté UI).
  static Future<String> createInvite(String accountId) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('account_invites')
        .insert({
          'account_id': accountId,
          'created_by': userId,
        })
        .select()
        .single();
    return row['code'] as String;
  }

  /// Rejoint un compte partagé à partir d'un code d'invitation.
  static Future<void> redeemInvite(String code) async {
    await _client.rpc('redeem_invite', params: {'invite_code': code});
  }

  /// Profils des membres d'un compte (id, email, display_name) — pour la
  /// gestion des membres, indépendamment du compte actif. Ne contient pas
  /// les revenus déclarés, contrairement à `AccountMembersStore` (dédié à
  /// l'écran Équité du compte actif).
  static Future<List<Map<String, dynamic>>> fetchMembers(
    String accountId,
  ) async {
    final memberRows = await _client
        .from('account_members')
        .select('user_id')
        .eq('account_id', accountId);
    final userIds =
        (memberRows as List).map((r) => r['user_id'] as String).toList();
    if (userIds.isEmpty) return [];

    final profiles =
        await _client.from('profiles').select().inFilter('id', userIds);
    return (profiles as List).cast<Map<String, dynamic>>();
  }

  /// Retire un membre d'un compte partagé — réservé au propriétaire du
  /// compte côté RLS (voir policy "owner can remove members").
  static Future<void> removeMember(String accountId, String userId) async {
    await _client
        .from('account_members')
        .delete()
        .eq('account_id', accountId)
        .eq('user_id', userId);
  }
}
