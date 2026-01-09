import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tag.dart';
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

  Future<Tag> addTag(String name, {int? color}) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    final Map<String, dynamic> data = {"name": name};
    if (color != null) data['color'] = color;

    final docRef = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("tags")
        .add(data);
    return Tag(id: docRef.id, name: name, color: color);
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
}
