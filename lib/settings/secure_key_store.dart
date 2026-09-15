import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Génère/retrouve la clé AES-256 utilisée pour chiffrer les boîtes Hive
/// locales (préférences de l'appareil) — la clé elle-même vit dans le
/// stockage sécurisé de l'OS (Keystore Android, Keychain iOS/macOS,
/// libsecret Linux, DPAPI Windows), jamais dans Hive ni dans le code.
class SecureKeyStore {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'stability_hive_key_v1';

  static Future<List<int>> _getOrCreateKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) {
      return base64Decode(existing);
    }

    final key = Hive.generateSecureKey();
    await _storage.write(key: _storageKey, value: base64Encode(key));
    return key;
  }

  /// Ouvre [boxName] chiffrée, en migrant silencieusement le contenu d'une
  /// éventuelle version non chiffrée déjà présente sur le disque (créée
  /// par une version antérieure de l'app). Si la migration échoue pour
  /// une raison quelconque (ex: plateforme sans stockage sécurisé
  /// disponible), retombe sur une boîte non chiffrée plutôt que de
  /// bloquer le démarrage de l'app — seules des préférences locales
  /// vivent ici, pas les données financières (sur Supabase).
  static Future<Box> openEncryptedBox(String boxName) async {
    try {
      final key = await _getOrCreateKey();
      final cipher = HiveAesCipher(key);

      if (!Hive.isBoxOpen(boxName)) {
        try {
          return await Hive.openBox(boxName, encryptionCipher: cipher);
        } on HiveError {
          // Boîte existante non chiffrée (ancienne version de l'app) : on
          // la relit en clair, puis on la remplace par une version
          // chiffrée avec le même contenu.
          final legacy = await Hive.openBox(boxName);
          final data = Map<dynamic, dynamic>.from(legacy.toMap());
          await legacy.close();
          await Hive.deleteBoxFromDisk(boxName);

          final migrated =
              await Hive.openBox(boxName, encryptionCipher: cipher);
          await migrated.putAll(data);
          return migrated;
        }
      }
      return Hive.box(boxName);
    } catch (_) {
      return Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
    }
  }
}

/// Sel aléatoire pour la dérivation de clé d'un fichier de sauvegarde.
String randomSaltBase64() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return base64Encode(bytes);
}

/// Dérive une clé AES-256 à partir d'une phrase de passe utilisateur, pour
/// le chiffrement des fichiers de sauvegarde exportés (portables entre
/// appareils, donc pas liés au stockage sécurisé de CET appareil comme
/// [SecureKeyStore]). Étirement PBKDF2-like par hachages SHA-256 répétés
/// via `package:crypto` — pas d'implémentation maison.
List<int> deriveKeyFromPassphrase(String passphrase, String saltBase64) {
  final salt = base64Decode(saltBase64);
  List<int> digest = utf8.encode(passphrase) + salt;
  for (var i = 0; i < 100000; i++) {
    digest = sha256.convert(digest).bytes;
  }
  return digest;
}
