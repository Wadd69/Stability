import 'package:hive/hive.dart';
import 'transaction.dart';
import 'package:stability/core/finance/transaction_type.dart';
import 'package:stability/core/finance/monthly_balances_store.dart';

// ✅ archives
import 'package:stability/core/archives/archives_store.dart';
import 'package:stability/core/archives/archived_month.dart';

class TransactionsStore {
  static const String _boxName = 'transactions';

  static late Box _box;
  static final List<Transaction> _transactions = [];

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    final List stored = _box.get('list', defaultValue: []);

    _transactions
      ..clear()
      ..addAll(
        stored.cast<Map>().map(
              (e) => Transaction.fromMap(
                Map<String, dynamic>.from(e),
              ),
            ),
      );
  }

  // ─────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────
  static String _monthKeyFromDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}-$m';
  }

  // ─────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────
  static List<Transaction> get all => List.unmodifiable(_transactions);

  // ─────────────────────────────────────────────
  // PERSISTENCE
  // ─────────────────────────────────────────────
  static void _save() {
    _box.put('list', _transactions.map((t) => t.toMap()).toList());
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────
  static void add(Transaction transaction) {
    _transactions.add(transaction);
    _save();
  }

  static void update({
    required String id,
    required String label,
    required double amount,
    required DateTime date,
    String? category,
    String? containerId,
  }) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final t = _transactions[index];

    _transactions[index] = t.copyWith(
      label: label,
      amount: amount,
      date: date,
      category: category,
      containerId: containerId ?? t.containerId,
      monthKey: _monthKeyFromDate(date),

      // Important : si on modifie une transaction, elle redevient "normale"
      isCarryOver: false,

      // ✅ si tu édites une transaction, elle redevient normale => on efface l’origine
      originMonthKey: null,
    );

    _save();
  }

  static void updateTransaction(Transaction updated) {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;

    final original = _transactions[index];
    final newMonthKey = _monthKeyFromDate(updated.date);

    if (original.transferId != null) {
      for (int i = 0; i < _transactions.length; i++) {
        final t = _transactions[i];
        if (t.transferId == original.transferId) {
          _transactions[i] = t.copyWith(
            label: updated.label,
            amount: updated.amount,
            date: updated.date,
            category: updated.category,
            isCleared: updated.isCleared,
            monthKey: newMonthKey,
            isArchived: t.isArchived,
            isCarryOver: false,
            originMonthKey: null, // ✅ redevient normale si édition
          );
        }
      }
    } else {
      _transactions[index] = original.copyWith(
        label: updated.label,
        amount: updated.amount,
        date: updated.date,
        category: updated.category,
        isCleared: updated.isCleared,
        monthKey: newMonthKey,
        isArchived: original.isArchived,
        isCarryOver: false,
        originMonthKey: null, // ✅
      );
    }

    _save();
  }

  static void clearAll() {
    _transactions.clear();
    _save();
  }

  static void remove(String id) {
    final target = _transactions.where((t) => t.id == id).toList();
    if (target.isEmpty) return;

    final t = target.first;

    if (t.transferId != null) {
      _transactions.removeWhere((e) => e.transferId == t.transferId);
    } else if (t.splitGroupId != null) {
      _transactions.removeWhere((e) => e.splitGroupId == t.splitGroupId);
    } else {
      _transactions.removeWhere((e) => e.id == id);
    }

    _save();
  }

  // ─────────────────────────────────────────────
  // CLÔTURE / ARCHIVAGE — COMPORTEMENT EXACT + PERSISTANCE SOLDES
  //
  // Pointées     -> archivées + trace
  // Non pointées -> passent au mois suivant, visibles, isCarryOver=true
  //                => visibles mais n'impactent pas le solde
  //
  // ✅ FIX doublon archives :
  // - une carryOver a originMonthKey != null
  // - elle ne doit JAMAIS apparaître dans l’archive du mois courant
  // - quand elle est finalement pointée, elle s’archive dans son mois d’origine
  // ─────────────────────────────────────────────
  static void closeMonth({
    required String monthKey,
    required String nextMonthKey,
  }) {
    final snapshot = List<Transaction>.from(_transactions);

    // 1) CALCUL DU SOLDE FINAL PAR CONTENEUR (AVANT DE MODIFIER LES TX)
    final containerIds = <String>{};

    containerIds.addAll(MonthlyBalancesStore.containerIdsForMonth(monthKey));

    for (final t in snapshot) {
      if (t.monthKey != monthKey) continue;
      if (t.isArchived) continue;
      final cid = t.containerId;
      if (cid != null) containerIds.add(cid);
    }

    for (final cid in containerIds) {
      final opening = MonthlyBalancesStore.getOpeningBalance(monthKey, cid);

      final movements = snapshot
          .where((t) =>
              t.monthKey == monthKey &&
              !t.isArchived &&
              t.containerId == cid &&
              !t.isCarryOver)
          .fold<double>(
            0,
            (sum, t) =>
                t.type == TransactionType.income ? sum + t.amount : sum - t.amount,
          );

      final endBalance = opening + movements;
      MonthlyBalancesStore.setOpeningBalance(nextMonthKey, cid, endBalance);
    }

    // 2) ARCHIVAGE / CARRYOVER
    final processedTransfers = <String>{};

    void updateOriginArchiveAsCleared(Transaction t) {
      final origin = t.originMonthKey;
      if (origin == null) return;

      // on essaye de mettre à jour l’archive du mois d’origine si elle existe
      final existing = ArchivesStore.all.where((m) => m.id == origin).toList();
      if (existing.isEmpty) return;

      final month = existing.first;

      final updatedTx = month.transactions.map((x) {
        if (x.id == t.id) {
          return x.copyWith(isCleared: true);
        }
        return x;
      }).toList();

      ArchivesStore.add(
        ArchivedMonth(
          id: month.id,
          year: month.year,
          month: month.month,
          label: month.label,
          transactions: updatedTx,
          totalIncome: month.totalIncome,
          totalExpense: month.totalExpense,
          balance: month.balance,
        ),
      );
    }

    void archiveWithTrace(Transaction t) {
      // ✅ si carryOver => on archive dans son mois d’origine
      final archiveMonthKey = t.originMonthKey ?? monthKey;

      _transactions.add(
        Transaction(
          id: '${t.id}_arch_$archiveMonthKey',
          label: t.label,
          amount: t.amount,
          date: t.date,
          type: t.type,
          category: t.category,
          containerId: t.containerId,
          transferId: t.transferId,
          isInterest: t.isInterest,
          isCleared: true,
          isArchived: true,
          isCarryOver: false,
          monthKey: archiveMonthKey,
          originMonthKey: t.originMonthKey,
        ),
      );

      final idx = _transactions.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _transactions[idx] = _transactions[idx].copyWith(
          isArchived: true,
          isCarryOver: false,
        );
      }

      // ✅ optionnel mais logique : si la tx vient d’un mois précédent,
      // on la marque comme pointée dans l’archive d’origine
      if (t.originMonthKey != null) {
        updateOriginArchiveAsCleared(t);
      }
    }

    void carryOverToNextMonth(Transaction t) {
      final idx = _transactions.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _transactions[idx] = _transactions[idx].copyWith(
          monthKey: nextMonthKey,
          isCleared: false,
          isArchived: false,
          isCarryOver: true,

          // ✅ on fixe le mois d’origine UNE FOIS
          originMonthKey: t.originMonthKey ?? monthKey,
        );
      }
    }

    for (final t in snapshot) {
      if (t.monthKey != monthKey || t.isArchived) continue;

      // Transferts : traités par paire
      if (t.transferId != null) {
        final transferId = t.transferId!;
        if (processedTransfers.contains(transferId)) continue;
        processedTransfers.add(transferId);

        final pair = snapshot.where((x) => x.transferId == transferId).toList();
        if (pair.isEmpty) continue;

        final allCleared = pair.every((x) => x.isCleared);

        if (allCleared) {
          for (final x in pair) {
            archiveWithTrace(x);
          }
        } else {
          for (final x in pair) {
            carryOverToNextMonth(x);
          }
        }
        continue;
      }

      if (t.isCleared) {
        archiveWithTrace(t);
      } else {
        carryOverToNextMonth(t);
      }
    }

    // 3) CRÉATION / MAJ ARCHIVE DU MOIS (SANS LES carryOver)
    final archivedTx = snapshot
        .where((t) =>
            t.monthKey == monthKey &&
            // ✅ exclure les carryOver : elles appartiennent à un mois précédent
            t.originMonthKey == null)
        .toList();

    double income = 0;
    double expense = 0;
    for (final t in archivedTx) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final prev = ArchivesStore.getPreviousMonth(year, month);
    final opening = prev?.balance ?? 0;

    ArchivesStore.add(
      ArchivedMonth(
        id: monthKey,
        year: year,
        month: month,
        label: monthKey,
        transactions: archivedTx,
        totalIncome: income,
        totalExpense: expense,
        balance: opening + income - expense,
      ),
    );

    _save();
  }

  // ─────────────────────────────────────────────
  // POINTAGE
  // ─────────────────────────────────────────────
  static void toggleCleared(String id) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final t = _transactions[index];
    _transactions[index] = t.copyWith(isCleared: !t.isCleared);

    _save();
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  static List<Transaction> transactionsForMonth(String monthKey) {
    return _transactions
        .where((t) => t.monthKey == monthKey && !t.isArchived)
        .toList();
  }

  static List<Transaction> byContainer(String? containerId) {
    return _transactions
        .where((t) => t.containerId == containerId && !t.isArchived)
        .toList();
  }

  /// Historique complet d'un support, tous mois confondus, y compris
  /// les mouvements archivés — utile pour les supports "réserve
  /// permanente" (épargne, projet, etc.) qui ne suivent pas le cycle
  /// mensuel du compte courant. On exclut uniquement les copies
  /// d'archive (id contenant "_arch_") pour ne jamais compter un
  /// même mouvement deux fois (l'original archivé + sa copie).
  static List<Transaction> historyByContainer(String? containerId) {
    return _transactions
        .where((t) => t.containerId == containerId && !t.id.contains('_arch_'))
        .toList();
  }

  /// Historique complet, tous supports et tous mois confondus, sans les
  /// doublons d'archive (même principe que [historyByContainer]). Base
  /// de tout écran listant/recherchant des transactions en dehors du
  /// contexte "mois actif" du dashboard.
  static List<Transaction> history() {
    return _transactions.where((t) => !t.id.contains('_arch_')).toList();
  }

  static double balanceByContainer(String? containerId) {
    final list = byContainer(containerId).where((t) => !t.isCarryOver);
    return list.fold<double>(
      0,
      (sum, t) =>
          t.type == TransactionType.income ? sum + t.amount : sum - t.amount,
    );
  }

  // ─────────────────────────────────────────────
  // INTÉRÊTS
  // ─────────────────────────────────────────────
  static void addInterestTransaction({
    required String containerId,
    required DateTime quinzaineDate,
    required double amount,
    required String containerName,
  }) {
    final alreadyExists = _transactions.any(
      (t) =>
          t.isInterest &&
          t.containerId == containerId &&
          t.date == quinzaineDate,
    );

    if (alreadyExists) return;

    _transactions.add(
      Transaction(
        id: 'interest_${containerId}_${quinzaineDate.toIso8601String()}',
        label:
            'Intérêts – ${quinzaineDate.day == 1 ? '01' : '16'}/${quinzaineDate.month.toString().padLeft(2, '0')}/${quinzaineDate.year}',
        amount: amount,
        date: quinzaineDate,
        type: TransactionType.income,
        containerId: containerId,
        isInterest: true,
        isCarryOver: false,
        monthKey: _monthKeyFromDate(quinzaineDate),
        originMonthKey: null,
      ),
    );

    _save();
  }
}
