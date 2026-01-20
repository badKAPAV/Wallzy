import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../tag/models/tag.dart';
import '../../tag/services/tag_info.dart';
import '../../auth/provider/auth_provider.dart';

class MetaProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider authProvider; // Changed from final
  StreamSubscription? _tagsSubscription;

  List<Tag> _tags = [];
  List<Tag> get tags => _tags;

  MetaProvider({required this.authProvider}) {
    if (authProvider.isLoggedIn) {
      _listenToData();
    }
  }

  /// 🔹 ADDED: Method to update the auth provider without losing state.
  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    // Re-listen to data for the potentially new user.
    if (authProvider.isLoggedIn) {
      _listenToData();
    } else {
      // If user logs out, clear data and cancel subscriptions.
      _tags = [];
      _tagsSubscription?.cancel();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tagsSubscription?.cancel();
    super.dispose();
  }

  void _listenToData() {
    final user = authProvider.user;
    if (user == null) return;
    _loadLocalPrefs();
    _listenToTags(user.uid);
  }

  void _listenToTags(String uid) async {
    _tagsSubscription?.cancel();

    // 1. CACHE FIRST
    try {
      final cacheSnapshot = await _firestore
          .collection("users")
          .doc(uid)
          .collection("tags")
          .get(const GetOptions(source: Source.cache));

      if (cacheSnapshot.docs.isNotEmpty) {
        _tags = cacheSnapshot.docs
            .map((doc) => Tag.fromMap(doc.id, doc.data()))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Tags cache load error: $e");
    }

    // 2. LIVE LISTENER
    _tagsSubscription = _firestore
        .collection("users")
        .doc(uid)
        .collection("tags")
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          _tags = snapshot.docs
              .map((doc) => Tag.fromMap(doc.id, doc.data()))
              .toList();
          notifyListeners();
        });
  }

  Future<Tag> addTag(
    String name, {
    int? color,
    double? tagBudget,
    TagBudgetResetFrequency? tagBudgetFrequency,
  }) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    final Map<String, dynamic> data = {"name": name};
    if (color != null) data['color'] = color;
    if (tagBudget != null) data['tagBudget'] = tagBudget;
    if (tagBudgetFrequency != null) {
      data['tagBudgetFrequency'] = tagBudgetFrequency.name;
    }
    // eventStartDate and eventEndDate are not usually set during simple creation
    // unless passed, but for now we handle them via update or add them here if needed.
    // Keeping it simple as per request.

    final docRef = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("tags")
        .add(data);
    return Tag(
      id: docRef.id,
      name: name,
      color: color,
      createdAt: DateTime.now(),
      tagBudget: tagBudget,
      tagBudgetFrequency: tagBudgetFrequency,
    );
  }

  Future<void> updateTag(Tag tag) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("tags")
        .doc(tag.id)
        .update(tag.toMap());
  }

  Future<void> deleteTag(String tagId) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("tags")
        .doc(tagId)
        .delete();
  }

  List<Tag> searchTags(String query) {
    if (query.isEmpty) return [];
    return _tags
        .where((tag) => tag.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // --- EVENT MODE & AUTO ADD LOGIC ---

  static const String _prefEventModeTags = 'event_mode_tag_ids';
  static const String _prefAutoAddTag =
      'auto_add_tag_id'; // LEGACY: For migration
  static const String _prefAutoAddTags = 'auto_add_tag_ids'; // NEW: List of IDs
  static const String _prefBudgetWarningTags =
      'budget_warning_tag_ids'; // NEW: Budget Warning

  Set<String> _eventModeTagIds = {};
  Set<String> _autoAddTagIds = {};
  Set<String> _budgetWarningTagIds = {};

  // Initialize Prefs (Call this after auth/provider init if possible, or lazy load)
  // Since we don't have a distinct init cycle here widely used, we'll load on demand or in constructor via async method if needed.
  // Ideally, call this when `_listenToData` starts.

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _eventModeTagIds = (prefs.getStringList(_prefEventModeTags) ?? []).toSet();
    _budgetWarningTagIds = (prefs.getStringList(_prefBudgetWarningTags) ?? [])
        .toSet();

    // Migration Logic
    final legacyAutoAddId = prefs.getString(_prefAutoAddTag);
    final newAutoAddList = prefs.getStringList(_prefAutoAddTags);

    if (newAutoAddList != null) {
      _autoAddTagIds = newAutoAddList.toSet();
    } else {
      // First run with new logic
      _autoAddTagIds = {};
      if (legacyAutoAddId != null) {
        _autoAddTagIds.add(legacyAutoAddId);
        // Save to new format and remove old
        await prefs.setStringList(_prefAutoAddTags, _autoAddTagIds.toList());
        await prefs.remove(_prefAutoAddTag);
      }
    }
    notifyListeners();
  }

  bool isEventModeEnabled(String tagId) => _eventModeTagIds.contains(tagId);

  bool isAutoAddEnabled(String tagId) => _autoAddTagIds.contains(tagId);

  bool isBudgetWarningEnabled(String tagId) =>
      _budgetWarningTagIds.contains(tagId);

  Future<void> setEventMode(String tagId, bool enabled) async {
    if (enabled) {
      _eventModeTagIds.add(tagId);
      // Automatically enable auto-add when enabling event mode
      await setAutoAddTag(tagId, true);
    } else {
      _eventModeTagIds.remove(tagId);
      // If disabling event mode, also disable auto-add if it was this tag
      if (_autoAddTagIds.contains(tagId)) {
        await setAutoAddTag(tagId, false);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefEventModeTags, _eventModeTagIds.toList());
    notifyListeners();
  }

  Future<void> setBudgetWarning(String tagId, bool enabled) async {
    if (enabled) {
      _budgetWarningTagIds.add(tagId);
    } else {
      _budgetWarningTagIds.remove(tagId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefBudgetWarningTags,
      _budgetWarningTagIds.toList(),
    );
    notifyListeners();
  }

  Future<void> setAutoAddTag(String tagId, bool enabled) async {
    if (!enabled) {
      _autoAddTagIds.remove(tagId);
    } else {
      // Overlap check REMOVED as per new requirements.
      // Multiple event mode tags can now be active simultaneously.
      _autoAddTagIds.add(tagId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefAutoAddTags, _autoAddTagIds.toList());
    notifyListeners();
  }

  List<Tag> getAutoAddTagsForDate(DateTime date) {
    if (_autoAddTagIds.isEmpty) return [];

    final List<Tag> matchingTags = [];

    for (final tagId in _autoAddTagIds) {
      final tag = _tags.firstWhere(
        (t) => t.id == tagId,
        orElse: () => Tag(id: '', name: '', createdAt: DateTime.now()),
      );

      if (tag.id.isEmpty) continue;

      if (tag.eventStartDate != null && tag.eventEndDate != null) {
        final start = tag.eventStartDate!;
        final end = tag.eventEndDate!.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );

        if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end)) {
          matchingTags.add(tag);
        }
      }
    }
    return matchingTags;
  }

  List<Tag> getActiveEventFolders() {
    // Return tags that have Event Mode enabled locally
    return _tags.where((t) => _eventModeTagIds.contains(t.id)).toList();
  }
}
