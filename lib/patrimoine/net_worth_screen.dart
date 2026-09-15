import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/containers/containers_store.dart';
import '../core/containers/container_model.dart';
import '../core/containers/container_type.dart';
import '../core/containers/capitalization_engine.dart';
import '../core/containers/crypto_price_service.dart';
import '../core/containers/stock_price_service.dart';
import '../core/finance/transactions_store.dart';
import '../core/finance/transaction_type.dart';
import '../core/finance/monthly_balances_store.dart';
import '../core/finance/active_month_store.dart';
import '../settings/app_settings_store.dart';
import '../help/help_screen.dart';
import '../help/help_topic.dart';
import '../theme/app_colors.dart';

class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  Map<String, double> _cryptoPrices = {};
  Map<String, double> _stockPrices = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPrices());
  }

  List<ContainerModel> get _investmentContainers => context
      .read<ContainersStore>()
      .active
      .where((c) => c.type == ContainerType.investmentAccount)
      .toList();

  Future<void> _refreshPrices() async {
    final containers = _investmentContainers;
    final coinIds = containers
        .expand((c) => c.cryptoHoldings.map((h) => h.coinId))
        .toList();
    final symbols =
        containers.expand((c) => c.stockHoldings.map((h) => h.symbol)).toList();

    if (coinIds.isEmpty && symbols.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final crypto = await CryptoPriceService.fetchPricesEur(coinIds);
      Map<String, double> stocks = {};
      if (symbols.isNotEmpty && AppSettingsStore.finnhubApiKey != null) {
        stocks = await StockPriceService.fetchPrices(symbols);
      }
      setState(() {
        _cryptoPrices = crypto;
        _stockPrices = stocks;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Impossible de récupérer les cours (pas de connexion ?)';
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // CALCUL DE VALEUR PAR SUPPORT
  // ─────────────────────────────────────────────

  double _standingValue(ContainerModel c) {
    return TransactionsStore.historyByContainer(c.id)
        .where((t) => !t.isCarryOver)
        .fold<double>(
          0,
          (s, t) =>
              t.type == TransactionType.income ? s + t.amount : s - t.amount,
        );
  }

  double _currentAccountValue(ContainerModel c, String monthKey) {
    final opening = MonthlyBalancesStore.getOpeningBalance(monthKey, c.id);
    final movements = TransactionsStore.transactionsForMonth(monthKey)
        .where((t) => t.containerId == c.id && !t.isCarryOver)
        .fold<double>(
          0,
          (s, t) =>
              t.type == TransactionType.income ? s + t.amount : s - t.amount,
        );
    return opening + movements;
  }

  double? _capitalizationValue(ContainerModel c) {
    final configured = c.insuranceOpenedAt != null &&
        c.insuranceAnnualRate != null &&
        c.insuranceInterestMode != null;

    final calculated = configured
        ? CapitalizationEngine.computeValue(
            container: c, atDate: DateTime.now())
        : null;

    return c.insuranceCorrectedValue ?? calculated;
  }

  double _cryptoValue(ContainerModel c) {
    return c.cryptoHoldings.fold<double>(0, (s, h) {
      final p = _cryptoPrices[h.coinId];
      return p == null ? s : s + h.quantity * p;
    });
  }

  double _stockValue(ContainerModel c) {
    return c.stockHoldings.fold<double>(0, (s, h) {
      final p = _stockPrices[h.symbol];
      return p == null ? s : s + h.quantity * p;
    });
  }

  double? _valueOfEur(ContainerModel c, String monthKey) {
    switch (c.type) {
      case ContainerType.currentAccount:
        return _currentAccountValue(c, monthKey);
      case ContainerType.savingsAccount:
      case ContainerType.cash:
      case ContainerType.projectFund:
      case ContainerType.other:
        return _standingValue(c);
      case ContainerType.insuranceLife:
      case ContainerType.retirementAccount:
        return _capitalizationValue(c);
      case ContainerType.investmentAccount:
        return _cryptoValue(c);
      case ContainerType.credit:
        // Une dette réduit le patrimoine net, contrairement aux autres
        // types de support qui l'augmentent.
        final remaining = c.creditRemainingBalance;
        return remaining == null ? null : -remaining;
    }
  }

  @override
  Widget build(BuildContext context) {
    final containers = context.watch<ContainersStore>().active;
    final monthKey = ActiveMonthStore.current;

    double totalEur = 0;
    double totalStocksUsd = 0;
    final rows = <(ContainerModel, double?)>[];

    for (final c in containers) {
      final value = _valueOfEur(c, monthKey);
      rows.add((c, value));
      totalEur += value ?? 0;
      if (c.type == ContainerType.investmentAccount) {
        totalStocksUsd += _stockValue(c);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrimoine'),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshPrices,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(topic: HelpTopic.netWorth),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: context.appColors.warning.withValues(alpha: 0.15),
              child: Text(_error!),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Patrimoine total'),
                const SizedBox(height: 4),
                Text(
                  '${totalEur.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (totalStocksUsd > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+ ${totalStocksUsd.toStringAsFixed(2)} \$ en actions/ETF '
                    '(non converti, hors total)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Aucun support'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final (container, value) = rows[index];
                      final stockValue =
                          container.type == ContainerType.investmentAccount
                              ? _stockValue(container)
                              : 0.0;
                      final neutral =
                          Theme.of(context).colorScheme.onSurfaceVariant;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: container.color,
                        ),
                        title: Text(container.name),
                        subtitle: Text(container.type.label),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              value == null
                                  ? 'Non configuré'
                                  : '${value.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: value == null ? neutral : null,
                              ),
                            ),
                            if (stockValue > 0)
                              Text(
                                '+${stockValue.toStringAsFixed(2)} \$',
                                style: TextStyle(fontSize: 11, color: neutral),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
