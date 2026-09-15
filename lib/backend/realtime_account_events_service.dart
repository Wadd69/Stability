import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Un événement d'activité sur un compte partagé (adhésion, modification).
/// Ne concerne PAS les transactions : celles-ci restent locales (Hive) et
/// ne sont pas encore synchronisées sur Supabase — voir la note dans
/// [RealtimeAccountEventsService].
class AccountEvent {
  final String message;
  final DateTime at;

  AccountEvent({required this.message, required this.at});
}

/// Notifications en temps réel pour les comptes partagés, basées sur
/// Supabase Realtime (`postgres_changes`) : adhésion/départ d'un membre,
/// modification du compte, et mouvements d'argent (transactions ajoutées,
/// modifiées ou supprimées) puisque ces données vivent maintenant sur
/// Supabase comme le reste.
class RealtimeAccountEventsService {
  RealtimeChannel? _channel;
  final _controller = StreamController<AccountEvent>.broadcast();

  Stream<AccountEvent> get events => _controller.stream;

  void subscribe(String accountId) {
    unsubscribe();

    _channel = Supabase.instance.client
        .channel('account_events_$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'account_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (payload) => _controller.add(
            AccountEvent(
              message: 'Un membre a rejoint le compte',
              at: DateTime.now(),
            ),
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'account_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (payload) => _controller.add(
            AccountEvent(
              message: 'Un membre a quitté le compte',
              at: DateTime.now(),
            ),
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'accounts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: accountId,
          ),
          callback: (payload) => _controller.add(
            AccountEvent(
              message: 'Le compte a été modifié',
              at: DateTime.now(),
            ),
          ),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final label = row['label'] as String? ?? 'Opération';
            final amount = (row['amount'] as num?)?.toDouble() ?? 0;
            _controller.add(
              AccountEvent(
                message:
                    'Nouvelle opération : $label (${amount.toStringAsFixed(2)} €)',
                at: DateTime.now(),
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: accountId,
          ),
          callback: (payload) => _controller.add(
            AccountEvent(
              message: 'Une opération a été supprimée',
              at: DateTime.now(),
            ),
          ),
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    unsubscribe();
    _controller.close();
  }
}
