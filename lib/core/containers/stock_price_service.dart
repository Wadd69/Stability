import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../settings/app_settings_store.dart';

/// Récupère les cours d'actions/ETF via l'API Finnhub.
/// Nécessite une clé API gratuite (voir écran Réglages).
/// Documentation : https://finnhub.io/docs/api/quote
///
/// ⚠️ Contrairement à la crypto (toujours convertie en euros par
/// CoinGecko), Finnhub renvoie le prix dans la devise native du
/// marché coté (le plus souvent le dollar US). On ne convertit pas
/// automatiquement : les valeurs actions sont affichées séparément
/// des valeurs crypto pour ne jamais additionner deux devises
/// différentes sans conversion.
class StockPriceService {
  static const _baseUrl = 'https://finnhub.io/api/v1/quote';

  static Future<double> fetchPrice(String symbol) async {
    final apiKey = AppSettingsStore.finnhubApiKey;
    if (apiKey == null) {
      throw Exception('Aucune clé API Finnhub configurée');
    }

    final uri = Uri.parse('$_baseUrl?symbol=$symbol&token=$apiKey');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Erreur réseau (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final price = (decoded['c'] as num?)?.toDouble();

    if (price == null || price == 0) {
      throw Exception('Symbole introuvable : $symbol');
    }

    return price;
  }

  /// Récupère chaque symbole séparément (l'API Finnhub ne propose pas
  /// de requête groupée sur son offre gratuite). Un symbole en échec
  /// n'empêche pas les autres d'être récupérés.
  static Future<Map<String, double>> fetchPrices(
    List<String> symbols,
  ) async {
    final result = <String, double>{};
    for (final symbol in symbols.toSet()) {
      try {
        result[symbol] = await fetchPrice(symbol);
      } catch (_) {
        // symbole ignoré, les autres continuent
      }
    }
    return result;
  }
}
