import 'package:supabase_flutter/supabase_flutter.dart';

import '../accounts/current_account.dart';
import '../backend/auth_repository.dart';
import 'account_member.dart';

/// Membres du compte actif (profils + revenus déclarés) — utilisé pour
/// le partage équitable des dépenses (voir [EquitySettlementService]).
/// N'a de sens que pour un compte partagé, mais reste rempli (avec un
/// seul membre) pour un compte solo sans traitement particulier.
class AccountMembersStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<AccountMember> _members = [];

  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _members.clear();
      return;
    }

    final memberRows = await _client
        .from('account_members')
        .select('user_id')
        .eq('account_id', accountId);
    final userIds =
        (memberRows as List).map((r) => r['user_id'] as String).toList();

    if (userIds.isEmpty) {
      _members.clear();
      return;
    }

    final profileRows =
        await _client.from('profiles').select().inFilter('id', userIds);
    final incomeRows = await _client
        .from('account_member_incomes')
        .select()
        .eq('account_id', accountId);

    final incomeByUser = <String, double>{
      for (final r in incomeRows as List)
        r['user_id'] as String: (r['monthly_income'] as num).toDouble(),
    };

    _members
      ..clear()
      ..addAll((profileRows as List).map((r) {
        final id = r['id'] as String;
        final email = r['email'] as String? ?? '';
        return AccountMember(
          userId: id,
          displayName: (r['display_name'] as String?)?.trim().isNotEmpty == true
              ? r['display_name'] as String
              : (email.isNotEmpty ? email.split('@').first : 'Membre'),
          email: email,
          monthlyIncome: incomeByUser[id] ?? 0,
        );
      }));
  }

  static List<AccountMember> get all => List.unmodifiable(_members);

  static AccountMember? getById(String userId) {
    try {
      return _members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Revenu mensuel déclaré par l'utilisateur connecté pour le compte actif.
  static Future<void> setMyIncome(double amount) async {
    final userId = AuthRepository.currentUser?.id;
    if (userId == null) return;
    await setIncomeForUser(userId, amount);
  }

  /// Revenu mensuel déclaré pour un membre donné du compte actif — permet
  /// à un membre de saisir le revenu d'un autre (ex: compte commun où une
  /// seule personne gère l'app), pas seulement le sien.
  static Future<void> setIncomeForUser(String userId, double amount) async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('account_member_incomes').upsert({
      'account_id': accountId,
      'user_id': userId,
      'monthly_income': amount,
    });

    final index = _members.indexWhere((m) => m.userId == userId);
    if (index != -1) {
      _members[index] = _members[index].copyWith(monthlyIncome: amount);
    }
  }
}
