import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'container_model.dart';
import 'containers_store.dart';
import 'crypto_holding.dart';
import 'crypto_price_service.dart';
import 'stock_holding.dart';
import 'stock_price_service.dart';
import '../../settings/app_settings_store.dart';
import '../../settings/settings_screen.dart';
import '../../help/help_screen.dart';
import '../../help/help_topic.dart';

class ContainerInvestmentScreen extends StatefulWidget {
  final ContainerModel container;

  const ContainerInvestmentScreen({
    super.key,
    required this.container,
  });

  @override
  State<ContainerInvestmentScreen> createState() =>
      _ContainerInvestmentScreenState();
}

class _ContainerInvestmentScreenState
    extends State<ContainerInvestmentScreen> {
  late List<CryptoHolding> _cryptoHoldings;
  late List<StockHolding> _stockHoldings;

  Map<String, double> _cryptoPrices = {};
  Map<String, double> _stockPrices = {};

  bool _loadingCrypto = false;
  bool _loadingStocks = false;
  String? _cryptoError;
  String? _stockError;

  @override
  void initState() {
    super.initState();
    _cryptoHoldings = List<CryptoHolding>.from(widget.container.cryptoHoldings);
    _stockHoldings = List<StockHolding>.from(widget.container.stockHoldings);
    _refreshCryptoPrices();
    _refreshStockPrices();
  }

  void _persist() {
    final updated = widget.container.copyWith(
      cryptoHoldings: _cryptoHoldings,
      stockHoldings: _stockHoldings,
    );
    context.read<ContainersStore>().updateContainer(updated);
  }

  // ─────────────────────────────────────────────
  // CRYPTO
  // ─────────────────────────────────────────────

  Future<void> _refreshCryptoPrices() async {
    if (_cryptoHoldings.isEmpty) return;
    setState(() {
      _loadingCrypto = true;
      _cryptoError = null;
    });
    try {
      final prices = await CryptoPriceService.fetchPricesEur(
        _cryptoHoldings.map((h) => h.coinId).toList(),
      );
      setState(() {
        _cryptoPrices = prices;
        _loadingCrypto = false;
      });
    } catch (_) {
      setState(() {
        _cryptoError = 'Impossible de récupérer les cours (pas de connexion ?)';
        _loadingCrypto = false;
      });
    }
  }

  Future<void> _addCrypto() async {
    CryptoAsset selected = CryptoCatalog.popular.first;
    final controller = TextEditingController();

    final result = await showDialog<CryptoHolding>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Ajouter une crypto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CryptoAsset>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Crypto'),
                items: CryptoCatalog.popular
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text('${a.label} (${a.symbol})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => selected = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantité'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity =
                    double.tryParse(controller.text.replaceAll(',', '.'));
                if (quantity == null || quantity <= 0) return;

                Navigator.pop(
                  context,
                  CryptoHolding(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    coinId: selected.coinId,
                    symbol: selected.symbol,
                    label: selected.label,
                    quantity: quantity,
                  ),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _cryptoHoldings.add(result));
    _persist();
    _refreshCryptoPrices();
  }

  Future<void> _editCryptoQuantity(CryptoHolding holding) async {
    final controller = TextEditingController(text: holding.quantity.toString());

    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Quantité — ${holding.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (quantity == null || quantity <= 0) return;

    setState(() {
      final index = _cryptoHoldings.indexWhere((h) => h.id == holding.id);
      if (index != -1) {
        _cryptoHoldings[index] = _cryptoHoldings[index].copyWith(quantity: quantity);
      }
    });
    _persist();
  }

  void _removeCrypto(CryptoHolding holding) {
    setState(() => _cryptoHoldings.removeWhere((h) => h.id == holding.id));
    _persist();
  }

  double get _totalCryptoValue {
    return _cryptoHoldings.fold<double>(0, (sum, h) {
      final price = _cryptoPrices[h.coinId];
      return price == null ? sum : sum + h.quantity * price;
    });
  }

  // ─────────────────────────────────────────────
  // ACTIONS / ETF
  // ─────────────────────────────────────────────

  Future<void> _refreshStockPrices() async {
    if (_stockHoldings.isEmpty) return;
    if (AppSettingsStore.finnhubApiKey == null) return;

    setState(() {
      _loadingStocks = true;
      _stockError = null;
    });
    try {
      final prices = await StockPriceService.fetchPrices(
        _stockHoldings.map((h) => h.symbol).toList(),
      );
      setState(() {
        _stockPrices = prices;
        _loadingStocks = false;
      });
    } catch (_) {
      setState(() {
        _stockError = 'Impossible de récupérer les cours (pas de connexion ?)';
        _loadingStocks = false;
      });
    }
  }

  Future<void> _addStock() async {
    if (AppSettingsStore.finnhubApiKey == null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clé API requise'),
          content: const Text(
            'Le suivi d\'actions/ETF nécessite une clé API Finnhub '
            '(gratuite). Configurez-la dans les Réglages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aller aux réglages'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }
      return;
    }

    final symbolController = TextEditingController();
    final quantityController = TextEditingController();
    String? errorText;

    final result = await showDialog<StockHolding>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Ajouter une action / ETF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Symbole (ex: AAPL, MSFT)',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantité'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final symbol = symbolController.text.trim().toUpperCase();
                final quantity = double.tryParse(
                  quantityController.text.replaceAll(',', '.'),
                );

                if (symbol.isEmpty || quantity == null || quantity <= 0) {
                  setModalState(() => errorText = 'Champs invalides');
                  return;
                }

                try {
                  await StockPriceService.fetchPrice(symbol);
                } catch (e) {
                  setModalState(() => errorText = 'Symbole introuvable');
                  return;
                }

                if (!context.mounted) return;

                Navigator.pop(
                  context,
                  StockHolding(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    symbol: symbol,
                    quantity: quantity,
                  ),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _stockHoldings.add(result));
    _persist();
    _refreshStockPrices();
  }

  Future<void> _editStockQuantity(StockHolding holding) async {
    final controller = TextEditingController(text: holding.quantity.toString());

    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Quantité — ${holding.symbol}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (quantity == null || quantity <= 0) return;

    setState(() {
      final index = _stockHoldings.indexWhere((h) => h.id == holding.id);
      if (index != -1) {
        _stockHoldings[index] = _stockHoldings[index].copyWith(quantity: quantity);
      }
    });
    _persist();
  }

  void _removeStock(StockHolding holding) {
    setState(() => _stockHoldings.removeWhere((h) => h.id == holding.id));
    _persist();
  }

  double get _totalStockValue {
    return _stockHoldings.fold<double>(0, (sum, h) {
      final price = _stockPrices[h.symbol];
      return price == null ? sum : sum + h.quantity * price;
    });
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.currency_bitcoin),
              title: const Text('Ajouter une crypto'),
              onTap: () {
                Navigator.pop(context);
                _addCrypto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Ajouter une action / ETF'),
              onTap: () {
                Navigator.pop(context);
                _addStock();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Investissement – ${widget.container.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.investment),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMenu,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          _sectionHeader(
            title: 'Crypto',
            totalLabel: '${_totalCryptoValue.toStringAsFixed(2)} €',
            loading: _loadingCrypto,
            onRefresh: _refreshCryptoPrices,
          ),
          if (_cryptoError != null) _errorBanner(_cryptoError!),
          if (_cryptoHoldings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune position crypto.'),
            )
          else
            ..._cryptoHoldings.map((h) {
              final price = _cryptoPrices[h.coinId];
              final value = price != null ? h.quantity * price : null;
              return ListTile(
                title: Text('${h.label} (${h.symbol})'),
                subtitle: Text(
                  price == null
                      ? '${h.quantity} — cours indisponible'
                      : '${h.quantity} × ${price.toStringAsFixed(2)} €',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value == null ? '—' : '${value.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeCrypto(h),
                    ),
                  ],
                ),
                onTap: () => _editCryptoQuantity(h),
              );
            }),

          const Divider(height: 32),

          _sectionHeader(
            title: 'Actions / ETF (\$)',
            totalLabel: '${_totalStockValue.toStringAsFixed(2)} \$',
            loading: _loadingStocks,
            onRefresh: _refreshStockPrices,
          ),
          if (_stockError != null) _errorBanner(_stockError!),
          if (AppSettingsStore.finnhubApiKey == null)
            ListTile(
              leading: const Icon(Icons.key, color: Colors.orange),
              title: const Text('Aucune clé API configurée'),
              subtitle: const Text('Nécessaire pour suivre des actions/ETF'),
              trailing: TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  setState(() {});
                },
                child: const Text('Réglages'),
              ),
            )
          else if (_stockHoldings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune position action/ETF.'),
            )
          else
            ..._stockHoldings.map((h) {
              final price = _stockPrices[h.symbol];
              final value = price != null ? h.quantity * price : null;
              return ListTile(
                title: Text(h.symbol),
                subtitle: Text(
                  price == null
                      ? '${h.quantity} — cours indisponible'
                      : '${h.quantity} × ${price.toStringAsFixed(2)} \$',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value == null ? '—' : '${value.toStringAsFixed(2)} \$',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeStock(h),
                    ),
                  ],
                ),
                onTap: () => _editStockQuantity(h),
              );
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String totalLabel,
    required bool loading,
    required VoidCallback onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: loading ? null : onRefresh,
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withValues(alpha: 0.15),
      child: Text(message),
    );
  }
}
