import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';
import 'package:wallzy/features/transaction/models/transaction.dart';

/// A model to encapsulate all possible filter criteria for transactions.
class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? categories;
  final List<Tag>? tags;
  final List<Person>? people;
  final List<String>? paymentMethods;
  final double? minAmount;
  final double? maxAmount;
  final String? type; // "income", "expense", or null for both

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categories,
    this.tags,
    this.people,
    this.paymentMethods,
    this.minAmount,
    this.maxAmount,
    this.type,
  });

  /// An empty filter that matches all transactions.
  static const TransactionFilter empty = TransactionFilter();

  /// Creates a new filter object with updated values.
  /// This is useful for immutably updating the filter state.
  /// Using `ValueGetter` allows us to differentiate between not providing a value
  /// and providing a `null` value (to clear a filter).
  TransactionFilter copyWith({
    ValueGetter<DateTime?>? startDate,
    ValueGetter<DateTime?>? endDate,
    ValueGetter<List<String>?>? categories,
    ValueGetter<List<Tag>?>? tags,
    ValueGetter<List<Person>?>? people,
    ValueGetter<List<String>?>? paymentMethods,
    ValueGetter<double?>? minAmount,
    ValueGetter<double?>? maxAmount,
    ValueGetter<String?>? type,
  }) {
    return TransactionFilter(
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      categories: categories != null ? categories() : this.categories,
      tags: tags != null ? tags() : this.tags,
      people: people != null ? people() : this.people,
      paymentMethods:
          paymentMethods != null ? paymentMethods() : this.paymentMethods,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
      type: type != null ? type() : this.type,
    );
  }

  /// Returns true if any filter other than the default is applied.
  bool get hasActiveFilters => this != empty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          const ListEquality().equals(categories, other.categories) &&
          const ListEquality().equals(tags, other.tags) &&
          const ListEquality().equals(people, other.people) &&
          const ListEquality().equals(paymentMethods, other.paymentMethods) &&
          minAmount == other.minAmount &&
          maxAmount == other.maxAmount &&
          type == other.type;

  @override
  int get hashCode =>
      Object.hash(
        startDate, endDate, type, minAmount, maxAmount,
        const ListEquality().hash(categories),
        const ListEquality().hash(tags),
        const ListEquality().hash(people),
        const ListEquality().hash(paymentMethods),
      );
}

/// A model to hold the results of a filter operation.
class FilterResult {
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpense;

  /// The calculated balance from the filtered transactions.
  double get balance => totalIncome - totalExpense;

  FilterResult({
    required this.transactions,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
  });

  /// An empty result state.
  static FilterResult empty = FilterResult(transactions: []);
}

class TransactionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider authProvider; // Changed from final
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

  /// 🔹 ADDED: Method to update the auth provider without losing state.
  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    // Re-listen to transactions for the potentially new user.
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

  /// 🔹 Get filtered transactions and calculate totals
  /// This method performs all filtering on the client side, which is necessary
  /// for complex queries that Firestore does not support on the server.
  /// It calculates the list, income, and expense in a single pass for efficiency.
  FilterResult getFilteredResults(TransactionFilter filter) {
    // Use .where() to apply all filters and create a new list.
    final filteredList = _transactions.where((t) {
      // Date filter (inclusive of start, exclusive of end)
      final inRange = (filter.startDate == null ||
              !t.timestamp.isBefore(filter.startDate!)) &&
          (filter.endDate == null || t.timestamp.isBefore(filter.endDate!));
      if (!inRange) return false;

      // Type filter
      final typeMatch = filter.type == null || t.type == filter.type;
      if (!typeMatch) return false;

      // Category filter
      final categoryMatch = filter.categories == null ||
          filter.categories!.isEmpty ||
          filter.categories!.contains(t.category);
      if (!categoryMatch) return false;

      // Payment Method filter
      final paymentMethodMatch = filter.paymentMethods == null ||
          filter.paymentMethods!.isEmpty ||
          filter.paymentMethods!.contains(t.paymentMethod);
      if (!paymentMethodMatch) return false;

      // Amount filter
      final amountMatch = (filter.minAmount == null || t.amount >= filter.minAmount!) &&
          (filter.maxAmount == null || t.amount <= filter.maxAmount!);
      if (!amountMatch) return false;

      // Tag filter (checks if any of transaction's tags are in the filter's tags)
      final tagMatch = filter.tags == null ||
          filter.tags!.isEmpty ||
          (t.tags?.any((txTag) => filter.tags!.any((fTag) => fTag.id == txTag.id)) ?? false);
      if (!tagMatch) return false;

      // Person filter
      final personMatch = filter.people == null ||
          filter.people!.isEmpty ||
          (t.people?.any((txPerson) => filter.people!.any((fPerson) => fPerson.id == txPerson.id)) ?? false);
      if (!personMatch) return false;

      return true;
    }).toList();

    // After filtering, calculate totals from the resulting list.
    double income = 0.0;
    double expense = 0.0;
    for (final t in filteredList) {
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expense += t.amount;
    }

    return FilterResult(
      transactions: filteredList,
      totalIncome: income,
      totalExpense: expense,
    );
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