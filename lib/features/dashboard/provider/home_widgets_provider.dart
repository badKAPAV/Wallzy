import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/dashboard/models/home_widget_model.dart';

class HomeWidgetsProvider extends ChangeNotifier {
  static const String _prefKey = 'active_home_widgets';
  List<HomeWidgetModel> _activeWidgets = [];
  String? _currentUserId;

  HomeWidgetsProvider(); // Removed _loadWidgets() from constructor

  List<HomeWidgetModel> get activeWidgets => _activeWidgets;

  // Initialize with User ID
  Future<void> init(String userId) async {
    if (_currentUserId == userId) return; // Already initialized for this user
    _currentUserId = userId;
    await _loadWidgets();
  }

  // Clear data (e.g. on logout)
  void clear() {
    _currentUserId = null;
    _activeWidgets = [];
    notifyListeners();
  }

  Future<void> _loadWidgets() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = '${_prefKey}_$_currentUserId';

      // Migration: If user-specific key doesn't exist but legacy does, migrate it.
      // This assumes the current data on device belongs to this user.
      if (!prefs.containsKey(userKey) && prefs.containsKey(_prefKey)) {
        final legacyData = prefs.getString(_prefKey);
        if (legacyData != null) {
          await prefs.setString(userKey, legacyData);
          await prefs.remove(_prefKey);
        }
      }

      final String? widgetsJson = prefs.getString(userKey);
      if (widgetsJson != null) {
        final List<dynamic> decoded = jsonDecode(widgetsJson);
        _activeWidgets = decoded
            .map((w) => HomeWidgetModel.fromJson(w))
            .toList();
        notifyListeners();
      } else {
        // No data for this user, start empty
        _activeWidgets = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading home widgets: $e");
    }
  }

  Future<void> _saveWidgets() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = '${_prefKey}_$_currentUserId';
      final String encoded = jsonEncode(
        _activeWidgets.map((w) => w.toJson()).toList(),
      );
      await prefs.setString(userKey, encoded);
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
