/// Un membre du compte partagé actif, avec son revenu déclaré — sert de
/// base au calcul de répartition équitable (voir [EquitySettlementService]).
class AccountMember {
  final String userId;
  final String displayName;
  final String email;
  final double monthlyIncome;

  const AccountMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.monthlyIncome,
  });

  AccountMember copyWith({double? monthlyIncome}) => AccountMember(
        userId: userId,
        displayName: displayName,
        email: email,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      );
}
