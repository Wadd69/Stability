import 'package:flutter/material.dart';
import 'container_type.dart';
import 'crypto_holding.dart';
import 'stock_holding.dart';

/// 🔹 Historique d’un taux d’intérêt
/// Chaque ligne représente un changement officiel de taux
class InterestRatePeriod {
  final double rate; // ex: 2.5 (% annuel)
  final DateTime fromDate; // date d’effet du taux

  InterestRatePeriod({
    required this.rate,
    required this.fromDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'rate': rate,
      'fromDate': fromDate.toIso8601String(),
    };
  }

  factory InterestRatePeriod.fromMap(Map<dynamic, dynamic> map) {
    return InterestRatePeriod(
      rate: (map['rate'] as num).toDouble(),
      fromDate: DateTime.parse(map['fromDate'] as String),
    );
  }
}

/// 🔹 Mode de calcul des intérêts Assurance-vie
enum InsuranceInterestMode {
  prorataTemporis, // Calcul proportionnel au temps investi
  fullYear, // Intérêt plein dès l’année du versement
}

/// Modèle de donnée pur :
/// représente un conteneur (compte, épargne, investissement, etc.)
class ContainerModel {
  final String id;
  String name;
  int colorValue;
  ContainerType type;

  /// 🔹 Compte courant principal
  /// Utilisé uniquement si type == currentAccount
  bool isPrimary;

  /// 🔹 Historique des taux d’intérêt
  /// Utilisé uniquement si type == savingsAccount
  final List<InterestRatePeriod> interestRates;

  // ─────────────────────────────────────────────
  // ASSURANCE-VIE — DONNÉES MÉTIER
  // Utilisées uniquement si type == insuranceLife
  // ─────────────────────────────────────────────

  /// Date d’ouverture du contrat
  final DateTime? insuranceOpenedAt;

  /// Taux annuel choisi par l’utilisateur (%)
  final double? insuranceAnnualRate;

  /// Mode de calcul des intérêts
  final InsuranceInterestMode? insuranceInterestMode;

  /// Valeur calculée automatiquement par l’app
  final double? insuranceCalculatedValue;

  /// Valeur corrigée manuellement par l’utilisateur (vérité finale)
  final double? insuranceCorrectedValue;

  // ─────────────────────────────────────────────
  // RETRAITE (PER) — DONNÉE MÉTIER SPÉCIFIQUE
  // Utilisée uniquement si type == retirementAccount.
  // Le reste du comportement (taux, capitalisation) réutilise les
  // champs "insurance*" ci-dessus : un PER en fonds euros suit le
  // même effet cliquet qu'une assurance-vie, seule la disponibilité
  // de l'argent diffère.
  // ─────────────────────────────────────────────

  /// Date à partir de laquelle l'épargne redevient disponible
  /// (retraite légale, ou date cible choisie par l'utilisateur)
  final DateTime? retirementUnlockDate;

  // ─────────────────────────────────────────────
  // INVESTISSEMENT — DONNÉE MÉTIER
  // Utilisée uniquement si type == investmentAccount.
  // La valeur n'est jamais stockée : elle est recalculée à partir
  // du cours de marché (CryptoPriceService).
  // ─────────────────────────────────────────────
  final List<CryptoHolding> cryptoHoldings;
  final List<StockHolding> stockHoldings;

  // ─────────────────────────────────────────────
  // CRÉDIT — DONNÉE MÉTIER
  // Utilisée uniquement si type == credit. Modèle volontairement simple :
  // mensualité saisie à la main (pas de calcul d'amortissement), capital
  // restant dû décrémenté automatiquement dès qu'un virement (manuel ou
  // récurrent) crédite ce support (voir
  // BudgetAutomationService.applyCreditRepayment).
  // ─────────────────────────────────────────────
  final CreditKind? creditKind;
  final double? creditOriginalAmount;
  final double? creditRemainingBalance;
  final double? creditMonthlyPayment;
  final double? creditAnnualRate;
  final DateTime? creditStartedAt;

  final DateTime createdAt;
  bool isArchived;
  int order;

  ContainerModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.type,
    this.isPrimary = false,
    List<InterestRatePeriod>? interestRates,

    // Assurance-vie
    this.insuranceOpenedAt,
    this.insuranceAnnualRate,
    this.insuranceInterestMode,
    this.insuranceCalculatedValue,
    this.insuranceCorrectedValue,

    // Retraite (PER)
    this.retirementUnlockDate,

    // Investissement
    List<CryptoHolding>? cryptoHoldings,
    List<StockHolding>? stockHoldings,

    // Crédit
    this.creditKind,
    this.creditOriginalAmount,
    this.creditRemainingBalance,
    this.creditMonthlyPayment,
    this.creditAnnualRate,
    this.creditStartedAt,
    required this.createdAt,
    this.isArchived = false,
    this.order = 0,
  })  : interestRates = interestRates ?? [],
        cryptoHoldings = cryptoHoldings ?? [],
        stockHoldings = stockHoldings ?? [];

  Color get color => Color(colorValue);

  /// 🔹 Valeur réelle du contrat Assurance-vie
  /// (la correction utilisateur écrase toujours le calcul)
  double? get insuranceValue {
    if (insuranceCorrectedValue != null) {
      return insuranceCorrectedValue;
    }
    return insuranceCalculatedValue;
  }

  /// 🔹 Récupère le taux applicable à une date donnée
  /// (le dernier taux dont la date <= date demandée)
  InterestRatePeriod? rateAt(DateTime date) {
    if (interestRates.isEmpty) return null;

    final sorted = [...interestRates]
      ..sort((a, b) => a.fromDate.compareTo(b.fromDate));

    InterestRatePeriod? current;

    for (final r in sorted) {
      if (!r.fromDate.isAfter(date)) {
        current = r;
      }
    }

    return current;
  }

  ContainerModel copyWith({
    String? name,
    int? colorValue,
    ContainerType? type,
    bool? isPrimary,
    List<InterestRatePeriod>? interestRates,

    // Assurance-vie
    DateTime? insuranceOpenedAt,
    double? insuranceAnnualRate,
    InsuranceInterestMode? insuranceInterestMode,
    double? insuranceCalculatedValue,
    double? insuranceCorrectedValue,

    // Retraite (PER)
    DateTime? retirementUnlockDate,

    // Investissement
    List<CryptoHolding>? cryptoHoldings,
    List<StockHolding>? stockHoldings,

    // Crédit
    CreditKind? creditKind,
    double? creditOriginalAmount,
    double? creditRemainingBalance,
    double? creditMonthlyPayment,
    double? creditAnnualRate,
    DateTime? creditStartedAt,
    bool? isArchived,
    int? order,
  }) {
    return ContainerModel(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isPrimary: isPrimary ?? this.isPrimary,
      interestRates: interestRates ?? this.interestRates,
      insuranceOpenedAt: insuranceOpenedAt ?? this.insuranceOpenedAt,
      insuranceAnnualRate: insuranceAnnualRate ?? this.insuranceAnnualRate,
      insuranceInterestMode:
          insuranceInterestMode ?? this.insuranceInterestMode,
      insuranceCalculatedValue:
          insuranceCalculatedValue ?? this.insuranceCalculatedValue,
      insuranceCorrectedValue:
          insuranceCorrectedValue ?? this.insuranceCorrectedValue,
      retirementUnlockDate: retirementUnlockDate ?? this.retirementUnlockDate,
      cryptoHoldings: cryptoHoldings ?? this.cryptoHoldings,
      creditKind: creditKind ?? this.creditKind,
      creditOriginalAmount: creditOriginalAmount ?? this.creditOriginalAmount,
      creditRemainingBalance:
          creditRemainingBalance ?? this.creditRemainingBalance,
      creditMonthlyPayment: creditMonthlyPayment ?? this.creditMonthlyPayment,
      creditAnnualRate: creditAnnualRate ?? this.creditAnnualRate,
      creditStartedAt: creditStartedAt ?? this.creditStartedAt,
      stockHoldings: stockHoldings ?? this.stockHoldings,
      createdAt: createdAt,
      isArchived: isArchived ?? this.isArchived,
      order: order ?? this.order,
    );
  }

  /// --- Sérialisation Supabase (colonnes en snake_case) ---
  /// Ne contient volontairement pas `account_id` : c'est le store
  /// (ContainersStore) qui l'ajoute au moment de l'insertion, à partir du
  /// compte actif — le modèle lui-même reste indépendant du compte.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'type': type.index,
      'is_primary': isPrimary,
      'interest_rates': interestRates.map((e) => e.toMap()).toList(),

      // Assurance-vie
      'insurance_opened_at': insuranceOpenedAt?.toIso8601String(),
      'insurance_annual_rate': insuranceAnnualRate,
      'insurance_interest_mode': insuranceInterestMode?.index,
      'insurance_calculated_value': insuranceCalculatedValue,
      'insurance_corrected_value': insuranceCorrectedValue,

      'retirement_unlock_date': retirementUnlockDate?.toIso8601String(),

      'crypto_holdings': cryptoHoldings.map((e) => e.toMap()).toList(),
      'stock_holdings': stockHoldings.map((e) => e.toMap()).toList(),

      // Crédit
      'credit_kind': creditKind?.index,
      'credit_original_amount': creditOriginalAmount,
      'credit_remaining_balance': creditRemainingBalance,
      'credit_monthly_payment': creditMonthlyPayment,
      'credit_annual_rate': creditAnnualRate,
      'credit_started_at': creditStartedAt?.toIso8601String(),

      'created_at': createdAt.toIso8601String(),
      'is_archived': isArchived,
      'sort_order': order,
    };
  }

  factory ContainerModel.fromMap(Map<dynamic, dynamic> map) {
    return ContainerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['color_value'] as int,
      type: ContainerType.values[map['type'] as int],
      isPrimary: map['is_primary'] as bool? ?? false,
      interestRates: (map['interest_rates'] as List<dynamic>?)
              ?.map(
                (e) => InterestRatePeriod.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          [],

      // Assurance-vie
      insuranceOpenedAt: map['insurance_opened_at'] != null
          ? DateTime.parse(map['insurance_opened_at'] as String)
          : null,
      insuranceAnnualRate: (map['insurance_annual_rate'] as num?)?.toDouble(),
      insuranceInterestMode: map['insurance_interest_mode'] != null
          ? InsuranceInterestMode.values[map['insurance_interest_mode'] as int]
          : null,
      insuranceCalculatedValue:
          (map['insurance_calculated_value'] as num?)?.toDouble(),
      insuranceCorrectedValue:
          (map['insurance_corrected_value'] as num?)?.toDouble(),

      retirementUnlockDate: map['retirement_unlock_date'] != null
          ? DateTime.parse(map['retirement_unlock_date'] as String)
          : null,

      cryptoHoldings: (map['crypto_holdings'] as List<dynamic>?)
              ?.map((e) => CryptoHolding.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .toList() ??
          [],

      stockHoldings: (map['stock_holdings'] as List<dynamic>?)
              ?.map((e) => StockHolding.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .toList() ??
          [],

      // Crédit
      creditKind: map['credit_kind'] != null
          ? CreditKind.values[map['credit_kind'] as int]
          : null,
      creditOriginalAmount: (map['credit_original_amount'] as num?)?.toDouble(),
      creditRemainingBalance:
          (map['credit_remaining_balance'] as num?)?.toDouble(),
      creditMonthlyPayment: (map['credit_monthly_payment'] as num?)?.toDouble(),
      creditAnnualRate: (map['credit_annual_rate'] as num?)?.toDouble(),
      creditStartedAt: map['credit_started_at'] != null
          ? DateTime.parse(map['credit_started_at'] as String)
          : null,

      createdAt: DateTime.parse(map['created_at'] as String),
      isArchived: map['is_archived'] as bool? ?? false,
      order: map['sort_order'] as int? ?? 0,
    );
  }
}
