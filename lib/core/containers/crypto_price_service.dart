import 'dart:convert';
import 'package:http/http.dart' as http;

/// Récupère les cours crypto via l'API publique CoinGecko
/// (gratuite, sans clé). Documentation :
/// https://docs.coingecko.com/docs/keyless-public-api
class CryptoPriceService {
  static const _baseUrl = 'https://api.coingecko.com/api/v3/simple/price';

  /// Retourne le prix en euros de chaque identifiant CoinGecko demandé.
  /// Lève une exception en cas d'échec réseau ou de réponse invalide —
  /// à l'appelant de garder le dernier prix connu en cas d'erreur.
  static Future<Map<String, double>> fetchPricesEur(
    List<String> coinIds,
  ) async {
    if (coinIds.isEmpty) return {};

    final ids = coinIds.toSet().join(',');
    final uri = Uri.parse('$_baseUrl?ids=$ids&vs_currencies=eur');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Erreur réseau (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return decoded.map((key, value) {
      final eur = (value as Map<String, dynamic>)['eur'];
      return MapEntry(key, (eur as num?)?.toDouble() ?? 0.0);
    });
  }
}
