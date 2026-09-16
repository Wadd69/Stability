import 'package:flutter_test/flutter_test.dart';
import 'package:stability/core/finance/interest_engine.dart';
import 'package:stability/core/finance/transaction.dart';
import 'package:stability/core/finance/transaction_type.dart';

Transaction _tx({
  required DateTime date,
  required TransactionType type,
  double amount = 100,
}) {
  return Transaction(
    id: 't',
    label: 'x',
    amount: amount,
    date: date,
    type: type,
    monthKey: '${date.year}-${date.month.toString().padLeft(2, '0')}',
  );
}

void main() {
  group('InterestEngine.effectiveDate (règle des quinzaines)', () {
    test('un versement avant le 16 rapporte à partir du 16 du même mois', () {
      final t = _tx(date: DateTime(2026, 3, 10), type: TransactionType.income);
      expect(InterestEngine.effectiveDate(t), DateTime(2026, 3, 16));
    });

    test('un versement le 16 ou après rapporte à partir du 1er du mois suivant',
        () {
      final t = _tx(date: DateTime(2026, 3, 16), type: TransactionType.income);
      expect(InterestEngine.effectiveDate(t), DateTime(2026, 4, 1));
    });

    test('un retrait avant le 16 arrête de rapporter dès le 1er du mois', () {
      final t = _tx(date: DateTime(2026, 3, 10), type: TransactionType.expense);
      expect(InterestEngine.effectiveDate(t), DateTime(2026, 3, 1));
    });

    test('un retrait le 16 ou après arrête de rapporter dès le 16', () {
      final t =
          _tx(date: DateTime(2026, 3, 20), type: TransactionType.expense);
      expect(InterestEngine.effectiveDate(t), DateTime(2026, 3, 16));
    });
  });
}
