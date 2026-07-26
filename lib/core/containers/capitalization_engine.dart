import '../finance/transactions_store.dart';
import '../finance/transaction_type.dart';
import 'container_model.dart';
import 'container_type.dart';

/// ─────────────────────────────────────────────
/// MOTEUR DE CAPITALISATION — fonds euros / cliquet
/// ─────────────────────────────────────────────
///
/// Modélise le comportement d'un support à "effet cliquet" :
/// une fois les intérêts d'une année inscrits, ils sont définitivement
/// acquis et deviennent eux-mêmes du capital qui rapporte l'année
/// suivante. C'est le fonctionnement réel des fonds euros, que l'on
/// retrouve aussi bien dans un contrat d'assurance-vie que dans la
/// partie "fonds euros" d'un Plan Épargne Retraite (PER) — d'où un
/// moteur commun aux deux types de support.
///
/// - Versements = income
/// - Rachats = expense
/// - ❌ intérêts (isInterest) ignorés
/// - ❌ copies d'archive (_arch_) ignorées
/// - Deux modes :
///   • prorataTemporis : estimation journalière réelle (valorisation
///     indicative avant l'inscription officielle des intérêts)
///   • fullYear : capitalisation par années civiles révolues (31/12),
///     conforme au fonctionnement officiel d'un fonds euros
class CapitalizationEngine {
  static double computeValue({
    required ContainerModel container,
    required DateTime atDate,
  }) {
    if (container.type != ContainerType.insuranceLife &&
        container.type != ContainerType.retirementAccount) {
      throw Exception('Mauvais type de support');
    }

    final openedAt = container.insuranceOpenedAt;
    final annualRate = container.insuranceAnnualRate;
    final mode = container.insuranceInterestMode;

    if (openedAt == null || annualRate == null || mode == null) {
      return 0;
    }

    final rate = annualRate / 100;

    // ✅ IMPORTANT :
    // - on ignore isInterest
    // - on ignore les copies d'archives (_arch_)
    // - on ignore ce qui est après atDate
    final tx = TransactionsStore.all
        .where((t) =>
            t.containerId == container.id &&
            !t.isInterest &&
            !t.id.contains('_arch_') &&
            !_isAfterDay(t.date, atDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double capital = 0;

    // ─────────────────────────────────────────
    // PRORATA TEMPORIS — JOURNALIER
    // ─────────────────────────────────────────
    if (mode == InsuranceInterestMode.prorataTemporis) {
      double interest = 0;

      DateTime day = _dateOnly(openedAt);
      final DateTime endDay = _dateOnly(atDate);

      int i = 0;

      while (!day.isAfter(endDay)) {
        while (i < tx.length && _sameDay(tx[i].date, day)) {
          final t = tx[i];
          capital += t.type == TransactionType.income ? t.amount : -t.amount;
          i++;
        }

        if (capital > 0) {
          interest += capital * rate / 365;
        }

        day = day.add(const Duration(days: 1));
      }

      return capital + interest;
    }

    // ─────────────────────────────────────────
    // INTÉRÊT PLEIN — ANNÉES CIVILES RÉVOLUES (FIN D'ANNÉE)
    //
    // - capital cumulatif (versements/rachats)
    // - à chaque fin d'année (31/12) passée, on capitalise :
    //   capital += capital * rate (effet cliquet)
    // ─────────────────────────────────────────
    final DateTime endDay = _dateOnly(atDate);

    int i = 0;

    final int startYear = openedAt.year;
    final int endYear = atDate.year;

    for (int year = startYear; year <= endYear; year++) {
      final DateTime yearEndDay = DateTime(year, 12, 31);

      while (i < tx.length && !_isAfterDay(tx[i].date, yearEndDay)) {
        final t = tx[i];
        capital += t.type == TransactionType.income ? t.amount : -t.amount;
        i++;
      }

      final bool yearIsClosed = !_isAfterDay(yearEndDay, endDay);

      if (yearIsClosed && capital > 0) {
        capital += capital * rate;
      }

      if (_isAfterDay(yearEndDay, endDay)) {
        break;
      }
    }

    return capital < 0 ? 0 : capital;
  }

  // ─────────────────────────────────────────────
  // HELPERS DATE (comparaison "jour" sans heure)
  // ─────────────────────────────────────────────

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isAfterDay(DateTime a, DateTime b) {
    final da = _dateOnly(a);
    final db = _dateOnly(b);
    return da.isAfter(db);
  }
}
