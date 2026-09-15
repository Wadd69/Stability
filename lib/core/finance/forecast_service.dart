import '../containers/container_model.dart';
import '../containers/container_type.dart';
import '../containers/containers_store.dart';
import 'active_month_store.dart';
import 'monthly_balances_store.dart';
import 'recurring_overrides_store.dart';
import 'recurring_transactions_store.dart';
import 'transaction_type.dart';
import 'transactions_store.dart';

/// Un mouvement prévu sur un support précis, pour l'écran Prévision.
/// [signedAmount] est déjà signé (+ = entrée, - = sortie) pour ce support,
/// et reflète déjà une éventuelle surcharge (voir [RecurringOverridesStore]).
class ForecastItem {
  final String label;
  final String? containerId;
  final double signedAmount;
  final DateTime date;

  /// Non nul et [editable] vrai si l'utilisateur peut corriger le montant
  /// de cette occurrence (ex: salaire dont le montant varie) — pas
  /// possible pour un virement scindé sur plusieurs destinations, où un
  /// seul montant global ne suffirait pas à répartir correctement.
  final String? recurringId;
  final String? overrideMonthKey;
  final bool editable;

  /// Vrai pour un virement interne entre deux supports du compte — ce
  /// n'est pas une nouvelle rentrée ou sortie d'argent, donc exclu de
  /// [MonthForecast.totalIncome] / [MonthForecast.totalExpense].
  final bool isTransfer;

  const ForecastItem({
    required this.label,
    required this.containerId,
    required this.signedAmount,
    required this.date,
    this.recurringId,
    this.overrideMonthKey,
    this.editable = false,
    this.isTransfer = false,
  });
}

class ContainerForecast {
  final ContainerModel container;
  final double currentBalance;
  final double projectedBalance;

  const ContainerForecast({
    required this.container,
    required this.currentBalance,
    required this.projectedBalance,
  });
}

class MonthForecast {
  final String monthKey;
  final List<ForecastItem> items;
  final List<ContainerForecast> containers;

  const MonthForecast({
    required this.monthKey,
    required this.items,
    required this.containers,
  });

  double get totalIncome => items
      .where((i) => !i.isTransfer && i.signedAmount > 0)
      .fold<double>(0, (s, i) => s + i.signedAmount);

  double get totalExpense => items
      .where((i) => !i.isTransfer && i.signedAmount < 0)
      .fold<double>(0, (s, i) => s + i.signedAmount.abs());
}

/// Calcule une prévision en lecture seule du mois suivant, à partir des
/// transactions récurrentes actives — sans jamais créer de transaction ni
/// toucher au mois actif. Le solde de départ de chaque support est son
/// solde réel actuel (voir [_standingValue], même calcul que l'écran
/// Patrimoine). Les montants tiennent compte des surcharges éventuelles
/// saisies dans l'écran Prévision (voir [RecurringOverridesStore]).
class ForecastService {
  static String _monthKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _nextMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return _monthKeyOf(DateTime(y, m + 1, 1));
  }

  static double _standingValue(ContainerModel c) {
    return TransactionsStore.historyByContainer(c.id)
        .where((t) => !t.isCarryOver)
        .fold<double>(
          0,
          (s, t) =>
              t.type == TransactionType.income ? s + t.amount : s - t.amount,
        );
  }

  /// Solde réel d'un compte courant : solde d'ouverture du mois actif +
  /// mouvements de ce mois-ci uniquement (jamais la somme de tout
  /// l'historique — les mois clôturés ne s'additionnent pas indéfiniment,
  /// voir `TransactionsStore.closeMonth`). Même calcul que l'écran
  /// Patrimoine, indispensable pour que le solde de départ affiché ici
  /// corresponde à la réalité.
  static double _currentAccountValue(ContainerModel c, String monthKey) {
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

  /// Vrai pour les types dont le solde a un sens monétaire simple (donc
  /// projetable directement à partir des récurrences) — exclut assurance-
  /// vie, investissement, retraite et crédit, dont la valeur dépend d'un
  /// modèle propre (capitalisation, cours de marché, capital restant dû)
  /// que la prévision ne recalcule pas.
  static bool _hasSimpleBalance(ContainerType type) {
    switch (type) {
      case ContainerType.currentAccount:
      case ContainerType.savingsAccount:
      case ContainerType.cash:
      case ContainerType.projectFund:
      case ContainerType.other:
        return true;
      case ContainerType.insuranceLife:
      case ContainerType.retirementAccount:
      case ContainerType.investmentAccount:
      case ContainerType.credit:
        return false;
    }
  }

  static double _currentValueOf(ContainerModel c, String activeMonthKey) {
    return c.type == ContainerType.currentAccount
        ? _currentAccountValue(c, activeMonthKey)
        : _standingValue(c);
  }

  static MonthForecast compute(ContainersStore containersStore) {
    final now = DateTime.now();
    final currentMonthKey = ActiveMonthStore.current;
    final nextMonthKey = _nextMonthKey(currentMonthKey);

    final items = <ForecastItem>[];

    for (final r in RecurringTransactionsStore.all) {
      if (!r.active) continue;

      final nextOcc = RecurringTransactionsStore.nextOccurrence(r, from: now);
      if (nextOcc == null) continue;

      final occMonthKey = _monthKeyOf(nextOcc);
      final inScope = occMonthKey == nextMonthKey ||
          (occMonthKey == currentMonthKey && r.countsForNextMonth);
      if (!inScope) continue;

      final legs = r.destinationLegs;
      final isSplitTransfer =
          r.type == TransactionType.transfer && legs != null && legs.isNotEmpty;

      final override = isSplitTransfer
          ? null
          : RecurringOverridesStore.getOverride(r.id, occMonthKey);
      final effectiveAmount = override ?? r.amount;

      if (r.type == TransactionType.transfer) {
        if (r.containerId == null) continue;

        // Le montant est éditable côté destination uniquement — un
        // virement simple n'a qu'un seul montant, pas la peine de le
        // rendre modifiable à deux endroits qui doivent rester égaux.
        items.add(ForecastItem(
          label: r.label,
          containerId: r.containerId,
          signedAmount: -effectiveAmount,
          date: nextOcc,
          isTransfer: true,
        ));

        if (isSplitTransfer) {
          for (final leg in legs) {
            items.add(ForecastItem(
              label: r.label,
              containerId: leg.containerId,
              signedAmount: leg.amount,
              date: nextOcc,
              isTransfer: true,
            ));
          }
        } else if (r.destinationContainerId != null) {
          items.add(ForecastItem(
            label: r.label,
            containerId: r.destinationContainerId,
            signedAmount: effectiveAmount,
            date: nextOcc,
            recurringId: r.id,
            overrideMonthKey: occMonthKey,
            editable: true,
            isTransfer: true,
          ));
        }
      } else {
        items.add(ForecastItem(
          label: r.label,
          containerId: r.containerId,
          signedAmount: r.type == TransactionType.income
              ? effectiveAmount
              : -effectiveAmount,
          date: nextOcc,
          recurringId: r.id,
          overrideMonthKey: occMonthKey,
          editable: true,
        ));
      }
    }

    final deltaByContainer = <String, double>{};
    for (final item in items) {
      final cid = item.containerId;
      if (cid == null) continue;
      deltaByContainer[cid] = (deltaByContainer[cid] ?? 0) + item.signedAmount;
    }

    final containerForecasts =
        containersStore.active.where((c) => _hasSimpleBalance(c.type)).map((c) {
      final current = _currentValueOf(c, currentMonthKey);
      return ContainerForecast(
        container: c,
        currentBalance: current,
        projectedBalance: current + (deltaByContainer[c.id] ?? 0),
      );
    }).toList();

    items.sort((a, b) => a.date.compareTo(b.date));

    return MonthForecast(
      monthKey: nextMonthKey,
      items: items,
      containers: containerForecasts,
    );
  }
}
