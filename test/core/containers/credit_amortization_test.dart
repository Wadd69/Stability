import 'package:flutter_test/flutter_test.dart';
import 'package:stability/core/containers/container_credit_screen.dart';

void main() {
  group('monthsLeftForCredit', () {
    test('sans taux, revient à capital / mensualité', () {
      expect(
        monthsLeftForCredit(remaining: 1200, monthly: 100, annualRate: 0),
        12,
      );
      expect(
        monthsLeftForCredit(remaining: 1200, monthly: 100, annualRate: null),
        12,
      );
    });

    test('avec taux, dure plus longtemps qu\'une simple division', () {
      // Crédit immobilier typique : ~200 000€ restants, mensualité 1000€,
      // taux 3.5% — la division simple donnerait 200 mois (~16.7 ans),
      // ignorer les intérêts en fait un exemple canonique du bug corrigé.
      final naive = (200000 / 1000).ceil();
      final real = monthsLeftForCredit(
        remaining: 200000,
        monthly: 1000,
        annualRate: 3.5,
      );

      expect(real, isNotNull);
      expect(real!, greaterThan(naive));
    });

    test('capital déjà remboursé', () {
      expect(
        monthsLeftForCredit(remaining: 0, monthly: 500, annualRate: 3),
        0,
      );
      expect(
        monthsLeftForCredit(remaining: -10, monthly: 500, annualRate: 3),
        0,
      );
    });

    test('mensualité qui ne couvre même pas les intérêts → jamais remboursé', () {
      // 100 000€ à 10%/an → ~833€/mois d'intérêts seuls.
      expect(
        monthsLeftForCredit(remaining: 100000, monthly: 500, annualRate: 10),
        isNull,
      );
    });

    test('données manquantes → null', () {
      expect(
        monthsLeftForCredit(remaining: null, monthly: 100, annualRate: 3),
        isNull,
      );
      expect(
        monthsLeftForCredit(remaining: 1000, monthly: null, annualRate: 3),
        isNull,
      );
      expect(
        monthsLeftForCredit(remaining: 1000, monthly: 0, annualRate: 3),
        isNull,
      );
    });
  });
}
