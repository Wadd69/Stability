/// Une position détenue dans un support de type investissement
/// (ex: 0.05 BTC). La valeur n'est jamais stockée : elle est
/// recalculée à partir du cours de marché récupéré via
/// [CryptoPriceService].
class CryptoHolding {
  final String id;
  final String coinId; // identifiant CoinGecko, ex: "bitcoin"
  final String symbol; // ex: "BTC"
  final String label; // ex: "Bitcoin"
  final double quantity;

  CryptoHolding({
    required this.id,
    required this.coinId,
    required this.symbol,
    required this.label,
    required this.quantity,
  });

  CryptoHolding copyWith({double? quantity}) {
    return CryptoHolding(
      id: id,
      coinId: coinId,
      symbol: symbol,
      label: label,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coinId': coinId,
      'symbol': symbol,
      'label': label,
      'quantity': quantity,
    };
  }

  factory CryptoHolding.fromMap(Map<dynamic, dynamic> map) {
    return CryptoHolding(
      id: map['id'] as String,
      coinId: map['coinId'] as String,
      symbol: map['symbol'] as String,
      label: map['label'] as String,
      quantity: (map['quantity'] as num).toDouble(),
    );
  }
}

/// Une crypto disponible à la sélection (catalogue restreint pour
/// éviter d'avoir à implémenter une recherche complète dans l'API
/// CoinGecko dès la première version).
class CryptoAsset {
  final String coinId;
  final String symbol;
  final String label;

  const CryptoAsset({
    required this.coinId,
    required this.symbol,
    required this.label,
  });
}

class CryptoCatalog {
  static const List<CryptoAsset> popular = [
    CryptoAsset(coinId: 'bitcoin', symbol: 'BTC', label: 'Bitcoin'),
    CryptoAsset(coinId: 'ethereum', symbol: 'ETH', label: 'Ethereum'),
    CryptoAsset(coinId: 'tether', symbol: 'USDT', label: 'Tether'),
    CryptoAsset(coinId: 'binancecoin', symbol: 'BNB', label: 'BNB'),
    CryptoAsset(coinId: 'solana', symbol: 'SOL', label: 'Solana'),
    CryptoAsset(coinId: 'usd-coin', symbol: 'USDC', label: 'USD Coin'),
    CryptoAsset(coinId: 'ripple', symbol: 'XRP', label: 'XRP'),
    CryptoAsset(coinId: 'cardano', symbol: 'ADA', label: 'Cardano'),
    CryptoAsset(coinId: 'dogecoin', symbol: 'DOGE', label: 'Dogecoin'),
    CryptoAsset(coinId: 'matic-network', symbol: 'MATIC', label: 'Polygon'),
  ];
}
