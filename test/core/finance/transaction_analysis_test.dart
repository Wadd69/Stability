import 'package:flutter_test/flutter_test.dart';
import 'package:stability/core/containers/containers_store.dart';
import 'package:stability/core/finance/transaction.dart';
import 'package:stability/core/finance/transaction_analysis.dart';
import 'package:stability/core/finance/transaction_type.dart';

Transaction _tx({
  required TransactionType type,
  String? transferId,
  double amount = 100,
}) {
  return Transaction(
    id: 't-${identityHashCode(type)}-$transferId-$amount',
    label: 'x',
    amount: amount,
    date: DateTime(2026, 1, 1),
    type: type,
    transferId: transferId,
    monthKey: '2026-01',
  );
}

void main() {
  // Aucun support "Crédit" injecté ici : couvre le cas général (virement
  // neutre) — le cas particulier "remboursement de crédit compte comme
  // dépense" nécessiterait d'injecter un ContainerModel de type crédit,
  // ce que ContainersStore n'expose pas sans passer par Supabase.
  final containersStore = ContainersStore();

  group('TransactionAnalysis', () {
    test('une dépense normale (pas un virement) compte', () {
      final t = _tx(type: TransactionType.expense);
      expect(
        TransactionAnalysis.countsAsExpense(t, [t], containersStore),
        isTrue,
      );
    });

    test('une rentrée normale (pas un virement) compte', () {
      final t = _tx(type: TransactionType.income);
      expect(TransactionAnalysis.countsAsIncome(t), isTrue);
    });

    test('un virement interne ne compte ni comme dépense ni comme rentrée',
        () {
      final out = _tx(type: TransactionType.expense, transferId: 'tr1');
      final inn = _tx(type: TransactionType.income, transferId: 'tr1');
      final all = [out, inn];

      expect(
        TransactionAnalysis.countsAsExpense(out, all, containersStore),
        isFalse,
      );
      expect(TransactionAnalysis.countsAsIncome(inn), isFalse);
    });

    test('filterForAnalysis ne garde que les mouvements réels', () {
      final expense = _tx(type: TransactionType.expense);
      final income = _tx(type: TransactionType.income);
      final transferOut = _tx(type: TransactionType.expense, transferId: 'tr2');
      final transferIn = _tx(type: TransactionType.income, transferId: 'tr2');

      final result = TransactionAnalysis.filterForAnalysis(
        [expense, income, transferOut, transferIn],
        containersStore,
      );

      expect(result, containsAll([expense, income]));
      expect(result, isNot(contains(transferOut)));
      expect(result, isNot(contains(transferIn)));
    });
  });
}
