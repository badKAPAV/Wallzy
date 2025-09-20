import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  Future<void> _createCashAccountForUser(String userId, bool makePrimary) async {
    final cashAccount = Account(
      id: '', // Firestore will generate
      bankName: 'Cash',
      accountNumber: '', // As requested
      accountHolderName: 'Me', // A sensible default
      userId: userId,
      isPrimary: makePrimary,
    );
    await _firestore.collection('accounts').add(cashAccount.toMap());
  }

  void _listenToAccounts(String userId) {
    _isLoading = true;
    notifyListeners();
    _accountSubscription = _firestore
        .collection('accounts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _accounts = snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      debugPrint("Error listening to accounts: $error");
      notifyListeners();
    });
  }

  Future<void> addAccount(Account account) async {
    if (_userId == null) return;
    // If this is the very first account, make it primary.
    final bool shouldBePrimary = _accounts.isEmpty;
    await _firestore.collection('accounts').add(
        account.copyWith(userId: _userId, isPrimary: shouldBePrimary).toMap());
    // The listener will update the local state.
  }

  Future<void> updateAccount(Account account) async {
    if (_userId == null) return;
    await _firestore.collection('accounts').doc(account.id).update(account.toMap());
  }

  Future<void> deleteAccount(String accountId) async {
    if (_userId == null) return;

    final accountToDelete = _accounts.firstWhere((acc) => acc.id == accountId,
        orElse: () => throw Exception("Account not found"));

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
    await _firestore.collection('accounts').doc(accountId).delete();
  }

  Future<void> setPrimaryAccount(String accountId) async {
    if (_userId == null) return;
    final batch = _firestore.batch();
    for (var account in _accounts) {
      final docRef = _firestore.collection('accounts').doc(account.id);
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
    // Query for an existing cash account for this user to prevent duplicates.
    final cashAccountQuery = await _firestore
        .collection('accounts')
        .where('userId', isEqualTo: userId)
        .where('bankName', isEqualTo: 'Cash')
        .limit(1)
        .get();

    // If no cash account is found in Firestore, then we create one.
    if (cashAccountQuery.docs.isEmpty) {
      // We still need to check if it should be primary.
      // It should be primary only if there are NO other accounts for this user.
      final anyAccountQuery = await _firestore.collection('accounts').where('userId', isEqualTo: userId).limit(1).get();
      await _createCashAccountForUser(userId, anyAccountQuery.docs.isEmpty);
    }
  }

  /// Finds an account by bank name and number. If not found, creates a new one.
  /// Returns the ID of the found or created account.
  Future<String> findOrCreateAccount({
    required String bankName,
    required String accountNumber,
    String? accountHolderName,
  }) async {
    if (_userId == null) throw Exception("User not logged in");

    // If the request is for a cash account, just return the existing one's ID.
    if (bankName.toLowerCase() == 'cash') {
      try {
        final cashAccount =
            _accounts.firstWhere((acc) => acc.bankName.toLowerCase() == 'cash');
        return cashAccount.id;
      } catch (e) {
        throw Exception("Cash account not found. Please restart the app.");
      }
    }

    // Rule: If an account number is provided, it's the primary key for matching.
    if (accountNumber.isNotEmpty) {
      try {
        // Find existing by account number ONLY.
        final existingAccount = _accounts.firstWhere(
            (acc) => acc.accountNumber == accountNumber && acc.accountNumber.isNotEmpty);
        return existingAccount.id;
      } catch (e) {
        // Not found, will proceed to create a new one below.
      }
    }

    // If we reach here, no existing account was found. Create a new one.
    final newAccount = Account(
      id: '', // Firestore will generate
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName ?? 'Main',
      userId: _userId!,
      isPrimary: _accounts.isEmpty, // Make primary if it's the first one
    );
    final docRef = await _firestore.collection('accounts').add(newAccount.toMap());
    return docRef.id;
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    super.dispose();
  }
}