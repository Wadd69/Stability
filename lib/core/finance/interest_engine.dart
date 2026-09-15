import 'transaction.dart';
import 'transaction_type.dart';
import 'transactions_store.dart';

class InterestLine {
  final DateTime quinzaineDate;
  final double capital;
  final double interest;

  InterestLine({
    required this.quinzaineDate,
    required this.capital,
    required this.interest,
  });
}

class InterestEngine {
  /// Génère toutes les quinzaines entre deux dates
  static List<DateTime> _generateQuinzaines(
    DateTime start,
    DateTime end,
  ) {
    final dates = <DateTime>[];

    DateTime current = DateTime(start.year, start.month, 1);

    while (!current.isAfter(end)) {
      dates.add(DateTime(current.year, current.month, 1));
      dates.add(DateTime(current.year, current.month, 16));

      current = DateTime(current.year, current.month + 1, 1);
    }

    return dates.where((d) => !d.isBefore(start) && !d.isAfter(end)).toList();
  }

  /// Date réelle de prise en compte d’une transaction
  static DateTime effectiveDate(Transaction t) {
    final d = t.date;

    if (t.type == TransactionType.income) {
      return d.day <= 15
          ? DateTime(d.year, d.month, 16)
          : DateTime(d.year, d.month + 1, 1);
    } else {
      return d.day <= 15
          ? DateTime(d.year, d.month, 1)
          : DateTime(d.year, d.month, 16);
    }
  }

  /// Calcul des intérêts par quinzaine pour un conteneur épargne
  static List<InterestLine> compute({
    required String containerId,
    required double annualRate,
    required DateTime from,
    required DateTime to,
  }) {
    final quinzaines = _generateQuinzaines(from, to);
    final lines = <InterestLine>[];

    for (final q in quinzaines) {
      double capital = 0;

      for (final t in TransactionsStore.all) {
        if (t.containerId != containerId) continue;
        if (t.isInterest) continue;

        final effective = effectiveDate(t);
        if (!effective.isAfter(q)) {
          capital += t.type == TransactionType.income ? t.amount : -t.amount;
        }
      }

      if (capital <= 0) continue;

      final interest = capital * (annualRate / 100) / 24;

      lines.add(
        InterestLine(
          quinzaineDate: q,
          capital: capital,
          interest: interest,
        ),
      );
    }

    return lines;
  }
}
