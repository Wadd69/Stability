/// Une position détenue en actions ou en ETF (ex: 3 parts AAPL).
/// Le prix n'est jamais stocké : il est recalculé via [StockPriceService].
class StockHolding {
  final String id;
  final String symbol; // ticker, ex: "AAPL", "VWCE.DE"
  final double quantity;

  StockHolding({
    required this.id,
    required this.symbol,
    required this.quantity,
  });

  StockHolding copyWith({double? quantity}) {
    return StockHolding(
      id: id,
      symbol: symbol,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbol': symbol,
      'quantity': quantity,
    };
  }

  factory StockHolding.fromMap(Map<dynamic, dynamic> map) {
    return StockHolding(
      id: map['id'] as String,
      symbol: map['symbol'] as String,
      quantity: (map['quantity'] as num).toDouble(),
    );
  }
}
