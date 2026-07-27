import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';

/// Mois actif du compte cloud actuel — une seule ligne par compte dans la
/// table Supabase `active_month`. Lecture synchrone (cache) ; [set] et
/// [advanceToNextMonth] font l'aller-retour réseau.
class ActiveMonthStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static String _current = _defaultMonthKey();

  static String _defaultMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _current = _defaultMonthKey();
      return;
    }

    final rows = await _client
        .from('active_month')
        .select()
        .eq('account_id', accountId)
        .limit(1);

    if (rows.isNotEmpty) {
      _current = rows.first['month_key'] as String;
    } else {
      _current = _defaultMonthKey();
      await _client.from('active_month').insert({
        'account_id': accountId,
        'month_key': _current,
      });
    }
  }

  static String get current => _current;

  static Future<void> set(String monthKey) async {
    _current = monthKey;

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('active_month').upsert({
      'account_id': accountId,
      'month_key': monthKey,
    });
  }

  /// Remet le mois actif au mois courant réel (reset dev/tests).
  static Future<void> clearAll() async {
    _current = _defaultMonthKey();

    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) return;

    await _client.from('active_month').upsert({
      'account_id': accountId,
      'month_key': _current,
    });
  }

  static Future<void> advanceToNextMonth() async {
    final parts = current.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);

    month++;
    if (month == 13) {
      month = 1;
      year++;
    }

    await set('$year-${month.toString().padLeft(2, '0')}');
  }
}
