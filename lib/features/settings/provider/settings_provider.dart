import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';

class SettingsProvider with ChangeNotifier {
  bool _autoRecordTransactions = false;

  BudgetCycleMode _budgetCycleMode = BudgetCycleMode.defaultMonth;
  int _budgetCycleStartDay = 1;

  // Currency Settings
  String _currencyCode = 'INR';
  String _currencySymbol = '₹';
  String _currencyIsoCodeNum = '356'; // India ISO Num
  bool _isSettingsLoaded = false;

  bool get autoRecordTransactions => _autoRecordTransactions;
  BudgetCycleMode get budgetCycleMode => _budgetCycleMode;
  int get budgetCycleStartDay => _budgetCycleStartDay;

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  String get currencyIsoCodeNum => _currencyIsoCodeNum;
  bool get isSettingsLoaded => _isSettingsLoaded;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRecordTransactions =
        prefs.getBool('auto_record_transactions') ?? false;

    // Load Budget Cycle Settings
    final modeIndex = prefs.getInt('budget_cycle_mode') ?? 0;
    _budgetCycleMode = BudgetCycleMode.values[modeIndex];
    _budgetCycleStartDay = prefs.getInt('budget_cycle_start_day') ?? 1;

    // Load Currency Settings
    _currencyCode = prefs.getString('currency_code') ?? 'INR';
    _currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    _currencyIsoCodeNum = prefs.getString('currency_iso_code_num') ?? '356';

    _isSettingsLoaded = true;
    notifyListeners();
  }

  Future<void> setAutoRecordTransactions(bool value) async {
    if (_autoRecordTransactions == value) return;
    _autoRecordTransactions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_transactions', value);
  }

  Future<void> setBudgetCycleMode(BudgetCycleMode mode) async {
    if (_budgetCycleMode == mode) return;
    _budgetCycleMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('budget_cycle_mode', mode.index);
  }

  Future<void> setBudgetCycleStartDay(int day) async {
    if (_budgetCycleStartDay == day) return;
    _budgetCycleStartDay = day;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('budget_cycle_start_day', day);
  }

  Future<void> setCurrency(
    String code,
    String symbol,
    String isoCodeNum,
  ) async {
    if (_currencyCode == code &&
        _currencySymbol == symbol &&
        _currencyIsoCodeNum == isoCodeNum)
      return;
    _currencyCode = code;
    _currencySymbol = symbol;
    _currencyIsoCodeNum = isoCodeNum;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    await prefs.setString('currency_symbol', symbol);
    await prefs.setString('currency_iso_code_num', isoCodeNum);
  }
}
