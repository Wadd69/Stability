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
/// Supabase Realtime (`postgres_changes`).
///
/// Limite importante : les transactions, catégories et supports restent
/// aujourd'hui purement locaux (Hive), seules les tables `accounts` et
/// `account_members` existent côté Supabase. Il n'est donc pas possible de
/// notifier "un tiers a fait un mouvement" — seuls les événements
/// d'adhésion et de modification du compte lui-même sont détectables ici.
/// Notifier les mouvements réels nécessiterait de migrer les transactions
/// vers Supabase (chantier séparé, plus important).
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
