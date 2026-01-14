import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/dashboard/models/home_widget_model.dart';

class HomeWidgetsProvider extends ChangeNotifier {
  static const String _prefKey = 'active_home_widgets';
  List<HomeWidgetModel> _activeWidgets = [];

  HomeWidgetsProvider() {
    _loadWidgets();
  }

  List<HomeWidgetModel> get activeWidgets => _activeWidgets;

  Future<void> _loadWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? widgetsJson = prefs.getString(_prefKey);
      if (widgetsJson != null) {
        final List<dynamic> decoded = jsonDecode(widgetsJson);
        _activeWidgets = decoded
            .map((w) => HomeWidgetModel.fromJson(w))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading home widgets: $e");
    }
  }

  Future<void> _saveWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _activeWidgets.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(_prefKey, encoded);
    } catch (e) {
      debugPrint("Error saving home widgets: $e");
    }
  }

  // Add a new empty widget
  void addWidget(HomeWidgetType type) {
    _activeWidgets.add(
      HomeWidgetModel(id: const Uuid().v4(), type: type, width: 4),
    );
    _saveWidgets();
    notifyListeners();
  }

  // Update widget configuration
  void updateWidgetConfig(String id, List<String> folderIds) {
    final index = _activeWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      // Update configIds
      _activeWidgets[index].configIds = List.from(folderIds);

      _saveWidgets();
      notifyListeners();
    }
  }

  void removeWidget(String id) {
    _activeWidgets.removeWhere((w) => w.id == id);
    _saveWidgets();
    notifyListeners();
  }
}
