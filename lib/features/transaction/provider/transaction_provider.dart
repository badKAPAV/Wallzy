import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

import '../../auth/provider/auth_provider.dart';

class TransactionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider authProvider;
  StreamSubscription? _transactionSubscription;

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isSaving = false;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  TransactionProvider({required this.authProvider}) {
    _listenToTransactions();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  /// 🔹 Listen to all transactions in real time
  void _listenToTransactions() {
    _transactionSubscription?.cancel();
    final user = authProvider.user;
    if (user == null) return;

    _transactionSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  /// 🔹 Add transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    final user = authProvider.user;
    if (user == null) return;

    _isSaving = true;
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.transactionId)
          .set(transaction.toMap());
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 🔹 Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    final user = authProvider.user;
    if (user == null) return;

    _isSaving = true;
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transaction.transactionId)
          .update(transaction.toMap());
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 🔹 Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    final user = authProvider.user;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  /// 🔹 ---------- CALCULATIONS & FILTERS ----------

  double getTotal({
    required DateTime start,
    required DateTime end,
    String? type, // "income" or "expense"
    List<String>? categories,
    List<Tag>? tags,
  }) {
    return _transactions.where((t) {
      // Inclusive of start, exclusive of end.
      final inRange = !t.timestamp.isBefore(start) && t.timestamp.isBefore(end);
      final typeMatch = type == null || t.type == type;
      final categoryMatch =
          categories == null || categories.contains(t.category);
      final tagMatch = tags == null ||
          t.tags!.any((tag) => tags.map((tg) => tg.id).contains(tag.id));

      return inRange && typeMatch && categoryMatch && tagMatch;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  /// 🔹 Quick Totals
  double get todayIncome => _getForDay(DateTime.now(), type: "income");
  double get todayExpense => _getForDay(DateTime.now(), type: "expense");

  double get yesterdayIncome =>
      _getForDay(DateTime.now().subtract(const Duration(days: 1)),
          type: "income");
  double get yesterdayExpense =>
      _getForDay(DateTime.now().subtract(const Duration(days: 1)),
          type: "expense");

  double get thisWeekIncome =>
      _getForRange(_startOfWeek(DateTime.now()), _endOfDay(DateTime.now()),
          type: "income");
  double get thisWeekExpense =>
      _getForRange(_startOfWeek(DateTime.now()), _endOfDay(DateTime.now()),
          type: "expense");

  double get lastWeekIncome {
    final lastWeekStart =
        _startOfWeek(DateTime.now()).subtract(const Duration(days: 7));
    final lastWeekEnd = _startOfWeek(DateTime.now())
        .subtract(const Duration(seconds: 1));
    return _getForRange(lastWeekStart, lastWeekEnd, type: "income");
  }

  double get lastWeekExpense {
    final lastWeekStart =
        _startOfWeek(DateTime.now()).subtract(const Duration(days: 7));
    final lastWeekEnd = _startOfWeek(DateTime.now())
        .subtract(const Duration(seconds: 1));
    return _getForRange(lastWeekStart, lastWeekEnd, type: "expense");
  }

  double get thisMonthIncome =>
      _getForRange(_startOfMonth(DateTime.now()), _endOfDay(DateTime.now()),
          type: "income");
  double get thisMonthExpense =>
      _getForRange(_startOfMonth(DateTime.now()), _endOfDay(DateTime.now()),
          type: "expense");

  double get lastMonthIncome {
    final firstDayThisMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final firstDayLastMonth =
        DateTime(firstDayThisMonth.year, firstDayThisMonth.month - 1, 1);
    return _getForRange(firstDayLastMonth,
        firstDayThisMonth.subtract(const Duration(seconds: 1)),
        type: "income");
  }

  double get lastMonthExpense {
    final firstDayThisMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final firstDayLastMonth =
        DateTime(firstDayThisMonth.year, firstDayThisMonth.month - 1, 1);
    return _getForRange(firstDayLastMonth,
        firstDayThisMonth.subtract(const Duration(seconds: 1)),
        type: "expense");
  }

  /// 🔹 Helpers
  double _getForDay(DateTime date, {String? type}) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getTotal(start: start, end: end, type: type);
  }

  double _getForRange(DateTime start, DateTime end, {String? type}) {
    return getTotal(start: start, end: end, type: type);
  }

  DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  DateTime _startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day).add(const Duration(days: 1));
}
