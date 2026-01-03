import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _autoRecordTransactions = false;

  bool get autoRecordTransactions => _autoRecordTransactions;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRecordTransactions =
        prefs.getBool('auto_record_transactions') ?? false;
    notifyListeners();
  }

  Future<void> setAutoRecordTransactions(bool value) async {
    if (_autoRecordTransactions == value) return;
    _autoRecordTransactions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_transactions', value);
  }
}
