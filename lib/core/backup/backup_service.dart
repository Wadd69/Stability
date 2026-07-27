import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/cloud_accounts_repository.dart';

/// Sauvegarde/restauration locale des données financières hébergées sur
/// Supabase (transactions, catégories, supports, budgets...). Un fichier
/// JSON reprend le contenu de chaque table pour tous les comptes dont
/// l'utilisateur est membre — pas seulement le compte actif. Les comptes
/// eux-mêmes (accounts/account_members) ne sont pas sauvegardés ici : ils
/// sont gérés côté Supabase indépendamment.
class BackupService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Tables financières, dans un ordre respectant les clés étrangères
  /// (containers avant categories/transactions, qui les référencent).
  static const List<String> tableNames = [
    'containers',
    'categories',
    'transactions',
    'category_allocations',
    'planned_income',
    'category_goals',
    'recurring_transactions',
    'archives',
    'monthly_balances',
    'active_month',
    'interest_adjustments',
  ];

  static Future<Directory> backupDirectory() async {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory('$home/StabilityBackups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _timestamp(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  /// Écrit un fichier de sauvegarde et retourne son chemin complet.
  static Future<String> exportToFile() async {
    final accounts = await CloudAccountsRepository.fetchMyAccounts();
    final accountIds = accounts.map((a) => a.id).toList();

    final tables = <String, dynamic>{};
    if (accountIds.isNotEmpty) {
      for (final table in tableNames) {
        final rows = await _client
            .from(table)
            .select()
            .inFilter('account_id', accountIds);
        tables[table] = rows;
      }
    }

    final payload = {
      'app': 'stability',
      'formatVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => {'id': a.id, 'name': a.name}).toList(),
      'tables': tables,
    };

    final dir = await backupDirectory();
    final file = File(
      '${dir.path}/stability-backup-${_timestamp(DateTime.now())}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  /// Liste les sauvegardes disponibles, la plus récente en premier.
  static Future<List<File>> listBackups() async {
    final dir = await backupDirectory();
    final files = dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        ).toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// Restaure une sauvegarde : upsert chaque ligne dans sa table Supabase
  /// d'origine (par compte/id déjà présents dans le fichier). Suppose que
  /// les comptes référencés existent toujours côté Supabase — sinon les
  /// lignes correspondantes seront rejetées par la contrainte de clé
  /// étrangère sur `account_id`.
  static Future<void> restoreFromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final tables = Map<String, dynamic>.from(decoded['tables'] as Map? ?? {});

    for (final tableName in tableNames) {
      final rawRows = tables[tableName];
      if (rawRows == null) continue;

      final rows = (rawRows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (rows.isEmpty) continue;

      await _client.from(tableName).upsert(rows);
    }
  }
}
