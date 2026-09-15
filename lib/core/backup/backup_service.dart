import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/cloud_accounts_repository.dart';
import '../../settings/secure_key_store.dart';

/// Exception dédiée pour une phrase de passe manquante/incorrecte à la
/// restauration — affichée telle quelle à l'utilisateur (pas une erreur
/// technique).
class BackupPassphraseError implements Exception {
  final String message;
  const BackupPassphraseError(this.message);
  @override
  String toString() => message;
}

/// Sauvegarde/restauration locale des données financières hébergées sur
/// Supabase (transactions, catégories, supports, budgets...). Un fichier
/// JSON — chiffré avec la phrase de passe fournie par l'utilisateur —
/// reprend le contenu de chaque table pour tous les comptes dont
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

  /// Écrit un fichier de sauvegarde chiffré (AES-256, clé dérivée de
  /// [passphrase]) et retourne son chemin complet — ce fichier contient
  /// l'intégralité des données financières de l'utilisateur, il ne doit
  /// jamais être écrit en clair sur le disque.
  static Future<String> exportToFile(String passphrase) async {
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
    final plainJson = jsonEncode(payload);

    final salt = randomSaltBase64();
    final key = enc.Key(Uint8List.fromList(
      deriveKeyFromPassphrase(passphrase, salt),
    ));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final cipherText = encrypter.encrypt(plainJson, iv: iv);

    final envelope = {
      'app': 'stability',
      'encrypted': true,
      'formatVersion': 2,
      'salt': salt,
      'iv': iv.base64,
      'cipherText': cipherText.base64,
    };

    final dir = await backupDirectory();
    final file = File(
      '${dir.path}/stability-backup-${_timestamp(DateTime.now())}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(envelope),
    );
    return file.path;
  }

  /// Liste les sauvegardes disponibles, la plus récente en premier.
  static Future<List<File>> listBackups() async {
    final dir = await backupDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.json'),
        )
        .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// Vrai si le fichier de sauvegarde est chiffré (donc nécessite une
  /// phrase de passe pour [restoreFromFile]) — à appeler avant de
  /// demander la phrase de passe à l'utilisateur, pour ne pas la
  /// réclamer inutilement sur une ancienne sauvegarde en clair.
  static Future<bool> isEncrypted(File file) async {
    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return decoded['encrypted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Restaure une sauvegarde : upsert chaque ligne dans sa table Supabase
  /// d'origine (par compte/id déjà présents dans le fichier). Suppose que
  /// les comptes référencés existent toujours côté Supabase — sinon les
  /// lignes correspondantes seront rejetées par la contrainte de clé
  /// étrangère sur `account_id`. [passphrase] est requis pour une
  /// sauvegarde chiffrée (voir [isEncrypted]) ; ignoré sinon (compatibilité
  /// avec d'anciennes sauvegardes en clair créées avant le chiffrement).
  static Future<void> restoreFromFile(File file, {String? passphrase}) async {
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final Map<String, dynamic> decoded;
    if (raw['encrypted'] == true) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupPassphraseError(
          'Cette sauvegarde est chiffrée : la phrase de passe est requise.',
        );
      }
      final salt = raw['salt'] as String;
      final key = enc.Key(Uint8List.fromList(
        deriveKeyFromPassphrase(passphrase, salt),
      ));
      final iv = enc.IV.fromBase64(raw['iv'] as String);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final String plainJson;
      try {
        plainJson = encrypter.decrypt64(raw['cipherText'] as String, iv: iv);
      } catch (_) {
        throw const BackupPassphraseError(
          'Phrase de passe incorrecte, ou fichier de sauvegarde corrompu.',
        );
      }
      decoded = jsonDecode(plainJson) as Map<String, dynamic>;
    } else {
      // Ancienne sauvegarde en clair, créée avant le chiffrement.
      decoded = raw;
    }

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
