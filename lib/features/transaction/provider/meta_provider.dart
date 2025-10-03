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

  void _listenToTags(String uid) {
    _tagsSubscription?.cancel();
    _tagsSubscription = _firestore.collection("users").doc(uid).collection("tags").snapshots().listen((snapshot) {
      _tags = snapshot.docs.map((doc) => Tag.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  Future<Tag> addTag(String name) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    final docRef = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("tags")
        .add({"name": name});
    return Tag(id: docRef.id, name: name);
  }

  List<Tag> searchTags(String query) {
    if (query.isEmpty) return [];
    return _tags
        .where((tag) => tag.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}