import '../core/finance/categories_store.dart';
import '../core/finance/recurring_transactions_store.dart';
import '../core/finance/transaction.dart';
import '../core/finance/transaction_type.dart';
import '../core/finance/transactions_store.dart';
import 'account_member.dart';
import 'account_members_store.dart';
import 'split_rule.dart';

class MemberSettlement {
  final AccountMember member;
  final double due;
  final double paid;

  const MemberSettlement({
    required this.member,
    required this.due,
    required this.paid,
  });

  /// Positif : les autres lui doivent de l'argent. Négatif : il/elle doit
  /// de l'argent aux autres.
  double get balance => paid - due;
}

class SuggestedTransfer {
  final AccountMember from;
  final AccountMember to;
  final double amount;

  const SuggestedTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });
}

class EquitySettlementResult {
  final List<MemberSettlement> members;
  final List<SuggestedTransfer> transfers;

  /// Total des dépenses sans "payé par" renseigné — leur part théorique
  /// est comptée dans [MemberSettlement.due], mais aucun membre n'est
  /// crédité du côté payé : le solde affiché est donc sous-estimé tant
  /// que ces dépenses ne sont pas complétées.
  final double totalUnassigned;

  const EquitySettlementResult({
    required this.members,
    required this.transfers,
    required this.totalUnassigned,
  });
}

/// Calcule, pour un compte partagé, combien chaque membre doit
/// théoriquement contribuer aux dépenses communes (selon les règles de
/// répartition par catégorie/récurrence) et combien il/elle a réellement
/// payé — pour en déduire qui doit rembourser combien à qui.
class EquitySettlementService {
  /// Remonte du gabarit de récurrence à partir de l'id déterministe
  /// `recurring_<templateId>_<monthKey>[_out|_in]` (voir
  /// `RecurringTransactionsStore.generateDueForMonth`) — évite d'avoir à
  /// stocker une référence supplémentaire sur chaque transaction générée.
  static String? _recurringTemplateId(String transactionId) {
    if (!transactionId.startsWith('recurring_')) return null;
    final parts = transactionId.split('_');
    if (parts.length < 3) return null;
    return parts[1];
  }

  static SplitRule resolveRule(Transaction t) {
    final templateId = _recurringTemplateId(t.id);
    if (templateId != null) {
      final template = RecurringTransactionsStore.all
          .where((r) => r.id == templateId)
          .toList();
      if (template.isNotEmpty && template.first.splitRule != null) {
        return template.first.splitRule!;
      }
    }

    if (t.category != null) {
      final category = CategoriesStore.getById(t.category!);
      if (category?.splitRule != null) return category!.splitRule!;
    }

    return SplitRule.proportional;
  }

  /// Part (0.0-1.0) de chaque membre pour une règle donnée. Se rabat sur
  /// une répartition égale si la règle choisie ne peut pas être évaluée
  /// (revenus tous à 0, membre assigné qui a quitté le compte...).
  static Map<String, double> computeShares(
    SplitRule rule,
    List<AccountMember> members,
  ) {
    if (members.isEmpty) return {};
    final equalShare = 1 / members.length;
    final equalShares = {for (final m in members) m.userId: equalShare};

    switch (rule.mode) {
      case SplitMode.equal:
        return equalShares;

      case SplitMode.assigned:
        final assignedId = rule.assignedUserId;
        if (assignedId == null || !members.any((m) => m.userId == assignedId)) {
          return equalShares;
        }
        return {
          for (final m in members) m.userId: m.userId == assignedId ? 1.0 : 0.0,
        };

      case SplitMode.custom:
        final percents = rule.customPercents;
        if (percents == null || percents.isEmpty) return equalShares;
        final total = percents.values.fold<double>(0, (s, v) => s + v);
        if (total <= 0) return equalShares;
        return {
          for (final m in members) m.userId: (percents[m.userId] ?? 0) / total,
        };

      case SplitMode.proportional:
        final totalIncome =
            members.fold<double>(0, (s, m) => s + m.monthlyIncome);
        if (totalIncome <= 0) return equalShares;
        return {
          for (final m in members) m.userId: m.monthlyIncome / totalIncome,
        };
    }
  }

  /// Solde du mois [monthKey] entre les membres du compte actif. Retourne
  /// une liste vide si le compte n'a pas au moins 2 membres (rien à
  /// équilibrer).
  static EquitySettlementResult computeForMonth(String monthKey) {
    final members = AccountMembersStore.all;
    if (members.length < 2) {
      return const EquitySettlementResult(
        members: [],
        transfers: [],
        totalUnassigned: 0,
      );
    }

    final due = {for (final m in members) m.userId: 0.0};
    final paid = {for (final m in members) m.userId: 0.0};
    double unassigned = 0;

    final expenses = TransactionsStore.all.where(
      (t) =>
          t.monthKey == monthKey &&
          t.type == TransactionType.expense &&
          !t.isArchived &&
          !t.isCarryOver &&
          t.transferId == null,
    );

    for (final t in expenses) {
      final shares = computeShares(resolveRule(t), members);
      shares.forEach((userId, share) {
        due[userId] = (due[userId] ?? 0) + t.amount * share;
      });

      final payer = t.paidByUserId;
      if (payer != null && paid.containsKey(payer)) {
        paid[payer] = (paid[payer] ?? 0) + t.amount;
      } else {
        unassigned += t.amount;
      }
    }

    final settlements = members
        .map((m) => MemberSettlement(
              member: m,
              due: due[m.userId] ?? 0,
              paid: paid[m.userId] ?? 0,
            ))
        .toList();

    return EquitySettlementResult(
      members: settlements,
      transfers: _settleUp(settlements),
      totalUnassigned: unassigned,
    );
  }

  /// Algorithme glouton "plus gros créancier ↔ plus gros débiteur" —
  /// minimise raisonnablement le nombre de virements suggérés sans viser
  /// l'optimalité stricte (largement suffisant pour un foyer).
  static List<SuggestedTransfer> _settleUp(List<MemberSettlement> settlements) {
    final creditors = settlements
        .where((s) => s.balance > 0.01)
        .map((s) => MapEntry(s.member, s.balance))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtors = settlements
        .where((s) => s.balance < -0.01)
        .map((s) => MapEntry(s.member, -s.balance))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final transfers = <SuggestedTransfer>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount =
          debtor.value < creditor.value ? debtor.value : creditor.value;

      if (amount > 0.01) {
        transfers.add(
          SuggestedTransfer(from: debtor.key, to: creditor.key, amount: amount),
        );
      }

      debtors[i] = MapEntry(debtor.key, debtor.value - amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);
      if (debtors[i].value <= 0.01) i++;
      if (creditors[j].value <= 0.01) j++;
    }
    return transfers;
  }
}
