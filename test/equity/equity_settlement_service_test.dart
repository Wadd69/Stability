import 'package:flutter_test/flutter_test.dart';
import 'package:stability/equity/account_member.dart';
import 'package:stability/equity/equity_settlement_service.dart';
import 'package:stability/equity/split_rule.dart';

AccountMember _member(String id, {double income = 0}) => AccountMember(
      userId: id,
      displayName: id,
      email: '$id@example.com',
      monthlyIncome: income,
    );

void main() {
  group('EquitySettlementService.computeShares', () {
    final members = [
      _member('a', income: 3000),
      _member('b', income: 1000),
    ];

    test('proportionnel aux revenus', () {
      final shares = EquitySettlementService.computeShares(
        SplitRule.proportional,
        members,
      );
      expect(shares['a'], closeTo(0.75, 0.0001));
      expect(shares['b'], closeTo(0.25, 0.0001));
    });

    test('parts égales', () {
      final shares =
          EquitySettlementService.computeShares(SplitRule.equal, members);
      expect(shares['a'], closeTo(0.5, 0.0001));
      expect(shares['b'], closeTo(0.5, 0.0001));
    });

    test('un seul membre paie', () {
      final shares = EquitySettlementService.computeShares(
        const SplitRule(mode: SplitMode.assigned, assignedUserId: 'b'),
        members,
      );
      expect(shares['a'], 0.0);
      expect(shares['b'], 1.0);
    });

    test('membre assigné qui a quitté le compte → repli sur parts égales', () {
      final shares = EquitySettlementService.computeShares(
        const SplitRule(mode: SplitMode.assigned, assignedUserId: 'inconnu'),
        members,
      );
      expect(shares['a'], closeTo(0.5, 0.0001));
      expect(shares['b'], closeTo(0.5, 0.0001));
    });

    test('pourcentages personnalisés', () {
      final shares = EquitySettlementService.computeShares(
        const SplitRule(
          mode: SplitMode.custom,
          customPercents: {'a': 70, 'b': 30},
        ),
        members,
      );
      expect(shares['a'], closeTo(0.7, 0.0001));
      expect(shares['b'], closeTo(0.3, 0.0001));
    });

    test('revenus tous à zéro → repli sur parts égales', () {
      final noIncome = [_member('a'), _member('b')];
      final shares = EquitySettlementService.computeShares(
        SplitRule.proportional,
        noIncome,
      );
      expect(shares['a'], closeTo(0.5, 0.0001));
      expect(shares['b'], closeTo(0.5, 0.0001));
    });
  });

  group('EquitySettlementService.settleUp', () {
    test('un débiteur, un créancier : un seul virement suffit', () {
      final settlements = [
        MemberSettlement(member: _member('a'), due: 100, paid: 200),
        MemberSettlement(member: _member('b'), due: 100, paid: 0),
      ];

      final transfers = EquitySettlementService.settleUp(settlements);

      expect(transfers, hasLength(1));
      expect(transfers.first.from.userId, 'b');
      expect(transfers.first.to.userId, 'a');
      expect(transfers.first.amount, closeTo(100, 0.01));
    });

    test('déjà équilibré : aucun virement', () {
      final settlements = [
        MemberSettlement(member: _member('a'), due: 100, paid: 100),
        MemberSettlement(member: _member('b'), due: 100, paid: 100),
      ];

      expect(EquitySettlementService.settleUp(settlements), isEmpty);
    });

    test('trois membres : le total des virements couvre toutes les dettes',
        () {
      final settlements = [
        MemberSettlement(member: _member('a'), due: 100, paid: 300),
        MemberSettlement(member: _member('b'), due: 100, paid: 100),
        MemberSettlement(member: _member('c'), due: 100, paid: 0),
      ];

      final transfers = EquitySettlementService.settleUp(settlements);
      final totalTransferred =
          transfers.fold<double>(0, (s, t) => s + t.amount);

      // a est créditeur de 200 (300 payé - 100 dû), b est à l'équilibre,
      // c est débiteur de 100 : un seul virement de c vers a suffit, à
      // hauteur du plus petit des deux déséquilibres (100).
      expect(transfers, hasLength(1));
      expect(transfers.first.from.userId, 'c');
      expect(transfers.first.to.userId, 'a');
      expect(totalTransferred, closeTo(100, 0.01));
    });
  });
}
