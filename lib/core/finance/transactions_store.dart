import 'package:supabase_flutter/supabase_flutter.dart';

import '../../accounts/current_account.dart';
import 'transaction.dart';
import 'package:stability/core/finance/transaction_type.dart';
import 'package:stability/core/finance/monthly_balances_store.dart';

// ✅ archives
import 'package:stability/core/archives/archives_store.dart';

class TransactionsStore {
  static SupabaseClient get _client => Supabase.instance.client;
  static final List<Transaction> _transactions = [];

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isEmpty) {
      _transactions.clear();
      return;
    }

    final rows = await _client
        .from('transactions')
        .select()
        .eq('account_id', accountId);

    _transactions
      ..clear()
      ..addAll(
        (rows as List).map((r) => Transaction.fromMap(r as Map<String, dynamic>)),
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
  // CRUD
  // ─────────────────────────────────────────────
  static Future<void> add(Transaction transaction) async {
    await _client.from('transactions').insert({
      ...transaction.toMap(),
      'account_id': CurrentAccount.active.id,
    });
    _transactions.add(transaction);
  }

  static Future<void> update({
    required String id,
    required String label,
    required double amount,
    required DateTime date,
    String? category,
    String? containerId,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final t = _transactions[index];

    final updated = t.copyWith(
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

    await _client.from('transactions').update(updated.toMap()).eq('id', id);
    _transactions[index] = updated;
  }

  static Future<void> updateTransaction(Transaction updated) async {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;

    final original = _transactions[index];
    final newMonthKey = _monthKeyFromDate(updated.date);

    final rowsToPersist = <Map<String, dynamic>>[];

    if (original.transferId != null) {
      for (int i = 0; i < _transactions.length; i++) {
        final t = _transactions[i];
        if (t.transferId == original.transferId) {
          final merged = t.copyWith(
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
          _transactions[i] = merged;
          rowsToPersist.add(merged.toMap());
        }
      }
    } else {
      final merged = original.copyWith(
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
      _transactions[index] = merged;
      rowsToPersist.add(merged.toMap());
    }

    if (rowsToPersist.isNotEmpty) {
      await _client.from('transactions').upsert(rowsToPersist);
    }
  }

  static Future<void> clearAll() async {
    final accountId = CurrentAccount.active.id;
    if (accountId.isNotEmpty) {
      await _client.from('transactions').delete().eq('account_id', accountId);
    }
    _transactions.clear();
  }

  static Future<void> remove(String id) async {
    final target = _transactions.where((t) => t.id == id).toList();
    if (target.isEmpty) return;

    final t = target.first;

    if (t.transferId != null) {
      await _client.from('transactions').delete().eq('transfer_id', t.transferId!);
      _transactions.removeWhere((e) => e.transferId == t.transferId);
    } else if (t.splitGroupId != null) {
      await _client
          .from('transactions')
          .delete()
          .eq('split_group_id', t.splitGroupId!);
      _transactions.removeWhere((e) => e.splitGroupId == t.splitGroupId);
    } else {
      await _client.from('transactions').delete().eq('id', id);
      _transactions.removeWhere((e) => e.id == id);
    }
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
  static Future<void> closeMonth({
    required String monthKey,
    required String nextMonthKey,
  }) async {
    final snapshot = List<Transaction>.from(_transactions);
    final rowsToUpsert = <Map<String, dynamic>>[];

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
      await MonthlyBalancesStore.setOpeningBalance(
        nextMonthKey,
        cid,
        endBalance,
      );
    }

    // 2) ARCHIVAGE / CARRYOVER
    // Note : plus besoin de mettre à jour l'archive du mois d'origine
    // quand une transaction reportée est enfin pointée — l'archive ne
    // stocke plus le détail des transactions (juste des totaux), et la
    // transaction elle-même est mise à jour via rowsToUpsert ci-dessous.
    final processedTransfers = <String>{};

    void archiveWithTrace(Transaction t) {
      // ✅ si carryOver => on archive dans son mois d’origine
      final archiveMonthKey = t.originMonthKey ?? monthKey;

      final archivedCopy = Transaction(
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
      );
      _transactions.add(archivedCopy);
      rowsToUpsert.add({
        ...archivedCopy.toMap(),
        'account_id': CurrentAccount.active.id,
      });

      final idx = _transactions.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _transactions[idx] = _transactions[idx].copyWith(
          isArchived: true,
          isCarryOver: false,
        );
        rowsToUpsert.add(_transactions[idx].toMap());
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
        rowsToUpsert.add(_transactions[idx].toMap());
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

    // 3) CRÉATION / MAJ DU RÉSUMÉ D'ARCHIVE DU MOIS (SANS LES carryOver)
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

    if (rowsToUpsert.isNotEmpty) {
      await _client.from('transactions').upsert(rowsToUpsert);
    }

    await ArchivesStore.archiveMonth(
      monthKey: monthKey,
      label: monthKey,
      totalIncome: income,
      totalExpense: expense,
      balance: opening + income - expense,
    );
  }

  // ─────────────────────────────────────────────
  // POINTAGE
  // ─────────────────────────────────────────────
  static Future<void> toggleCleared(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final t = _transactions[index];
    final updated = t.copyWith(isCleared: !t.isCleared);

    await _client
        .from('transactions')
        .update({'is_cleared': updated.isCleared}).eq('id', id);
    _transactions[index] = updated;
  }

  /// Force explicitement l'état pointé (contrairement à [toggleCleared],
  /// qui inverse toujours l'état courant) — utile pour une validation en
  /// masse où l'état cible est connu à l'avance.
  static Future<void> setCleared(String id, bool value) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final t = _transactions[index];
    final updated = t.copyWith(isCleared: value);

    await _client
        .from('transactions')
        .update({'is_cleared': value}).eq('id', id);
    _transactions[index] = updated;
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

  /// Transactions archivées d'un mois donné (remplace l'ancien
  /// `ArchivedMonth.transactions`, désormais normalisé hors de la table
  /// des archives — voir [ArchivesStore]).
  static List<Transaction> archivedForMonth(String monthKey) {
    return _transactions
        .where((t) => t.monthKey == monthKey && t.isArchived)
        .toList();
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
  static Future<void> addInterestTransaction({
    required String containerId,
    required DateTime quinzaineDate,
    required double amount,
    required String containerName,
  }) async {
    final alreadyExists = _transactions.any(
      (t) =>
          t.isInterest &&
          t.containerId == containerId &&
          t.date == quinzaineDate,
    );

    if (alreadyExists) return;

    final transaction = Transaction(
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
    );

    await _client.from('transactions').insert({
      ...transaction.toMap(),
      'account_id': CurrentAccount.active.id,
    });
    _transactions.add(transaction);
  }
}
