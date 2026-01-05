import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';

class SettingsProvider with ChangeNotifier {
  bool _autoRecordTransactions = false;

  BudgetCycleMode _budgetCycleMode = BudgetCycleMode.defaultMonth;
  int _budgetCycleStartDay = 1;

  bool get autoRecordTransactions => _autoRecordTransactions;
  BudgetCycleMode get budgetCycleMode => _budgetCycleMode;
  int get budgetCycleStartDay => _budgetCycleStartDay;

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
}
