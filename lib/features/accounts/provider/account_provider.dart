import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';
import 'package:wallzy/features/accounts/models/account.dart';

class AccountProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Account> _accounts = [];
  StreamSubscription? _accountSubscription;
  String? _userId;
  bool _isLoading = false;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  Account? get primaryAccount {
    try {
      return _accounts.firstWhere((acc) => acc.isPrimary);
    } catch (e) {
      return _accounts.isNotEmpty ? _accounts.first : null;
    }
  }

  Future<Account?> getPrimaryAccount() async {
    // Prefer the cached list if available and not empty.
    if (_accounts.isNotEmpty) {
      try {
        return _accounts.firstWhere((acc) => acc.isPrimary);
      } catch (e) {
        return _accounts
            .first; // Fallback to the first account if no primary is set
      }
    }

    if (_userId == null) return null;
    final accountsCollection = _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts');

    // Optimization: Check cache first to avoid blocking.
    try {
      final cacheQuery = await accountsCollection
          .where('isPrimary', isEqualTo: true)
          .limit(1)
          .get(const GetOptions(source: Source.cache));
      if (cacheQuery.docs.isNotEmpty) {
        return Account.fromFirestore(cacheQuery.docs.first, userId: _userId!);
      }
    } catch (e) {
      // Ignore cache miss/error
    }

    // Fallback: Just return null vs blocking on server. offline-first priority.
    // The listener should eventually update the list.
    return null;
  }

  Future<void> updateUser(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _accountSubscription?.cancel();
    _accounts = [];

    if (userId != null) {
      // Ensure a cash account exists for the user before we start listening.
      // This handles creation for new users or migration for existing ones.
      await _ensureCashAccountExists(userId);
      _listenToAccounts(userId);
    } else {
      notifyListeners();
    }
  }

  Future<void> _createCashAccountForUser(
    String userId,
    bool makePrimary,
  ) async {
    final cashAccount = Account(
      id: 'cash_$userId', // Deterministic ID
      bankName: 'Cash',
      accountNumber: '',
      accountHolderName: 'Me',
      userId: userId,
      isPrimary: makePrimary,
      accountType: 'debit',
    );
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc('cash_$userId')
        .set(cashAccount.toMap());
  }

  void _listenToAccounts(String userId) {
    _isLoading = true;
    notifyListeners();
    _accountSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .snapshots()
        .listen(
          (snapshot) {
            _accounts = snapshot.docs
                .map((doc) => Account.fromFirestore(doc, userId: userId))
                .toList();
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            _isLoading = false;
            debugPrint("Error listening to accounts: $error");
            notifyListeners();
          },
        );
  }

  Future<void> addAccount(Account account) async {
    if (_userId == null) return;
    // If this is the very first account, make it primary.
    final bool shouldBePrimary = _accounts.isEmpty;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts')
        .add(
          account.copyWith(userId: _userId, isPrimary: shouldBePrimary).toMap(),
        );
    // The listener will update the local state.
  }

  Future<void> updateAccount(Account account) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts')
        .doc(account.id)
        .update(account.toMap());
  }

  Future<void> deleteAccount(String accountId) async {
    if (_userId == null) return;

    final accountToDelete = _accounts.firstWhere(
      (acc) => acc.id == accountId,
      orElse: () => throw Exception("Account not found"),
    );

    // Rule: The "Cash" account cannot be deleted.
    if (accountToDelete.bankName.toLowerCase() == 'cash') {
      debugPrint("Deletion of 'Cash' account is not allowed.");
      return;
    }

    // If deleting the primary account, make another one primary if possible.
    if (accountToDelete.isPrimary && _accounts.length > 1) {
      final newPrimary = _accounts.firstWhere((acc) => acc.id != accountId);
      await setPrimaryAccount(newPrimary.id);
    }
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts')
        .doc(accountId)
        .delete();
  }

  Future<void> setPrimaryAccount(String accountId) async {
    if (_userId == null) return;
    final batch = _firestore.batch();
    final accountsCollection = _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts');
    for (var account in _accounts) {
      final docRef = accountsCollection.doc(account.id);
      if (account.id == accountId) {
        batch.update(docRef, {'isPrimary': true});
      } else if (account.isPrimary) {
        batch.update(docRef, {'isPrimary': false});
      }
    }
    await batch.commit();
  }

  /// Checks if a cash account exists for the user and creates one if not.
  Future<void> _ensureCashAccountExists(String userId) async {
    final accountsCollection = _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts');

    // Check for the deterministic cash account document directly.
    final cashDocRef = accountsCollection.doc('cash_$userId');

    bool exists = false;
    try {
      // First try to check cache. This is fast and offline-safe.
      final docSnapshot = await cashDocRef.get(
        const GetOptions(source: Source.cache),
      );
      exists = docSnapshot.exists;
    } catch (e) {
      // Not in cache or error.
      exists = false;
    }

    if (!exists) {
      // Double check: if we didn't find deterministic doc in cache,
      // check if we have a legacy "Cash" account in cache?
      try {
        final oldCashQuery = await accountsCollection
            .where('bankName', isEqualTo: 'Cash')
            .limit(1)
            .get(const GetOptions(source: Source.cache));
        if (oldCashQuery.docs.isNotEmpty) {
          return; // Legacy account exists in cache.
        }
      } catch (e) {
        // Ignore cache miss/error
      }

      // If we get here, safe to attempt creation.
      // We do need to know if we should make it primary.
      bool shouldBePrimary = true;
      try {
        final anyAccountQuery = await accountsCollection
            .limit(1)
            .get(const GetOptions(source: Source.cache));
        shouldBePrimary = anyAccountQuery.docs.isEmpty;
      } catch (e) {
        shouldBePrimary = true;
      }

      await _createCashAccountForUser(userId, shouldBePrimary);
    }
  }

  /// Finds an account by bank name and number. If not found, creates a new one.
  /// Returns the ID of the found or created account.
  /// Finds an account by bank name and number. If not found, creates a new one.
  /// Returns the ID of the found or created account.
  Future<Account> findOrCreateAccount({
    required String bankName,
    required String accountNumber,
    String? accountHolderName,
  }) async {
    if (_userId == null) throw Exception("User not logged in");

    final accountsCollection = _firestore
        .collection('users')
        .doc(_userId)
        .collection('accounts');

    // If the request is for a cash account, just return the existing one.
    if (bankName.toLowerCase() == 'cash') {
      try {
        final cashAccount = _accounts.firstWhere(
          (acc) => acc.bankName.toLowerCase() == 'cash',
        );
        return cashAccount;
      } catch (e) {
        // Not in in-memory list. Check Firestore cache first.
        try {
          final cashQuery = await accountsCollection
              .where('bankName', isEqualTo: 'Cash')
              .limit(1)
              .get(const GetOptions(source: Source.cache));

          if (cashQuery.docs.isNotEmpty) {
            return Account.fromFirestore(
              cashQuery.docs.first,
              userId: _userId!,
            );
          }
        } catch (_) {
          // Cache miss
        }

        // If critical for logic, we might need to await server, but risk ANR.
        // Given offline-first, if not in cache, it likely doesn't exist or we can't get it.
        // But for "Cash" specifically we have a deterministic ID now!
        try {
          final doc = await accountsCollection
              .doc('cash_$_userId')
              .get(const GetOptions(source: Source.cache));
          if (doc.exists) return Account.fromFirestore(doc, userId: _userId!);
        } catch (_) {}

        // If we still haven't found it, and we are offline, we should probably create one or fail.
        // Let's assume creation logic elsewhere handles init.
        // For now, allow a server check if absolutely necessary but it's risky.
        // Let's throw for now to see if we can avoid blocking.
        // Or return a dummy? No.
        // Let's fallback to standard get() but acknowledge risk.
        // Actually, wait! The user said "all data on device".
        // So cache miss = doesn't exist.
        throw Exception("Cash account not found locally.");
      }
    }

    // 1. In-Memory Fuzzy Search (Best for SMS partial numbers)
    if (accountNumber.isNotEmpty) {
      try {
        // Try strict match first
        final strictMatch = _accounts.firstWhere(
          (acc) => acc.accountNumber == accountNumber,
        );
        return strictMatch;
      } catch (_) {
        // Try fuzzy match (endsWith)
        // Only if length is sufficient to avoid false positives (e.g., > 3 digits)
        if (accountNumber.length >= 3) {
          try {
            final fuzzyMatch = _accounts.firstWhere(
              (acc) =>
                  acc.accountNumber.isNotEmpty &&
                  acc.accountNumber.endsWith(accountNumber),
            );
            return fuzzyMatch;
          } catch (_) {}
        }
      }
    }

    // 2. Firestore Strict Match (Rule: If an account number is provided, it's the primary key)
    if (accountNumber.isNotEmpty) {
      // Check cache first
      try {
        final querySnapshot = await accountsCollection
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get(const GetOptions(source: Source.cache));

        if (querySnapshot.docs.isNotEmpty) {
          return Account.fromFirestore(
            querySnapshot.docs.first,
            userId: _userId!,
          );
        }
      } catch (_) {}

      // If not in cache, we assume it's a new account or not synced.
      // Proceed to create (idempotent-ish if we rely on add() returning new ID).
    }

    // If we reach here, no existing account was found. Create a new one.
    // Check if any accounts exist for this user in the DB to determine 'isPrimary'.
    bool shouldBePrimary = true;
    try {
      final anyAccountQuery = await accountsCollection
          .limit(1)
          .get(const GetOptions(source: Source.cache));
      shouldBePrimary = anyAccountQuery.docs.isEmpty;
    } catch (_) {
      shouldBePrimary = true;
    }

    final newAccount = Account(
      id: '', // Firestore will generate
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName ?? 'Main',
      userId: _userId!,
      isPrimary: shouldBePrimary,
      accountType: 'debit',
    );
    final docRef = await accountsCollection.add(newAccount.toMap());
    final createdAccount = newAccount.copyWith(id: docRef.id);

    // Optimistically add to local list to avoid re-creation on next check
    _accounts.add(createdAccount);
    notifyListeners();

    return createdAccount;
  }

  /// Calculates the balance for a given account based on its type and transactions.
  double getBalanceForAccount(
    Account account,
    List<TransactionModel> allTransactions,
  ) {
    final accountTransactions = allTransactions.where(
      (tx) => tx.accountId == account.id,
    );

    if (account.accountType == 'credit') {
      // For credit cards, balance is negative of the amount due.
      // Due amount = (purchases) - (repayments + refunds).
      double due = 0;
      for (final tx in accountTransactions) {
        if (tx.category == 'Credit Repayment' || tx.type == 'income') {
          due -= tx.amount; // Repayments and refunds decrease the due amount
        } else if (tx.type == 'expense') {
          due += tx.amount; // Purchases increase the due amount
        }
      }
      return -due; // Return as negative because it's money owed.
    } else {
      // For debit/cash accounts, balance = income - expense.
      final income = accountTransactions
          .where((tx) => tx.type == 'income')
          .fold(0.0, (sum, tx) => sum + tx.amount);
      final expense = accountTransactions
          .where((tx) => tx.type == 'expense')
          .fold(0.0, (sum, tx) => sum + tx.amount);
      return income - expense;
    }
  }

  /// 🔹 Calculates the total available liquid cash across all non-credit accounts.
  /// This sums up the balance of all 'debit' and 'cash' accounts.
  double getTotalAvailableCash(List<TransactionModel> allTransactions) {
    double total = 0.0;
    for (final account in _accounts) {
      if (account.accountType.toLowerCase() != 'credit') {
        total += getBalanceForAccount(account, allTransactions);
      }
    }
    return total;
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    super.dispose();
  }
}
