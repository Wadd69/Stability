import 'package:home_widget/home_widget.dart';

import 'recurring_transaction.dart';
import 'recurring_transactions_store.dart';
import 'transaction_type.dart';

const _kAndroidWidgetProvider = 'RecurringWidgetProvider';
const _kMaxItems = 5;

const _kMonthNames = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Pousse les prochaines transactions récurrentes vers le widget d'écran
/// d'accueil Android ("ce qui reste à passer"). Silencieux en cas d'échec
/// (widget non ajouté à l'écran d'accueil, plateforme non supportée...) —
/// ce n'est qu'un affichage secondaire, pas une fonctionnalité bloquante.
class RecurringWidgetService {
  static Future<void> refresh() async {
    try {
      final now = DateTime.now();
      final upcoming = <MapEntry<RecurringTransaction, DateTime>>[];

      for (final r in RecurringTransactionsStore.all) {
        final date = RecurringTransactionsStore.nextOccurrence(r, from: now);
        if (date == null) continue;
        upcoming.add(MapEntry(r, date));
      }

      upcoming.sort((a, b) => a.value.compareTo(b.value));
      final items = upcoming.take(_kMaxItems).toList();

      final text = items.isEmpty
          ? 'Aucune échéance à venir'
          : items.map((e) => _formatLine(e.key, e.value)).join('\n');

      await HomeWidget.saveWidgetData<String>('recurring_text', text);
      await HomeWidget.updateWidget(
        androidName: _kAndroidWidgetProvider,
        qualifiedAndroidName: 'com.example.stability.$_kAndroidWidgetProvider',
      );
    } catch (_) {
      // Widget natif indisponible (émulateur sans launcher, plateforme
      // desktop en dev, etc.) — on ignore silencieusement.
    }
  }

  static String _formatLine(RecurringTransaction r, DateTime date) {
    final sign = r.type == TransactionType.expense ? '-' : '+';
    final amount = _formatAmount(r.amount);
    final day = date.day;
    final month = _kMonthNames[date.month - 1];
    return '${r.label}  $sign$amount €  ($day $month)';
  }

  static String _formatAmount(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final posFromEnd = str.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
