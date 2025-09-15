import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tag.dart';
import '../models/person.dart';
import '../../auth/provider/auth_provider.dart';

class MetaProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthProvider authProvider;
  StreamSubscription? _tagsSubscription;
  StreamSubscription? _peopleSubscription;

  List<Tag> _tags = [];
  List<Person> _people = [];

  List<Tag> get tags => _tags;
  List<Person> get people => _people;

  MetaProvider({required this.authProvider}) {
    if (authProvider.isLoggedIn) {
      _listenToData();
    }
  }

  @override
  void dispose() {
    _tagsSubscription?.cancel();
    _peopleSubscription?.cancel();
    super.dispose();
  }

  void _listenToData() {
    final user = authProvider.user;
    if (user == null) return;
    _listenToTags(user.uid);
    _listenToPeople(user.uid);
  }

  void _listenToTags(String uid) {
    _tagsSubscription?.cancel();
    _tagsSubscription = _firestore.collection("users").doc(uid).collection("tags").snapshots().listen((snapshot) {
      _tags = snapshot.docs.map((doc) => Tag.fromMap(doc.id, doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToPeople(String uid) {
    _peopleSubscription?.cancel();
    _peopleSubscription = _firestore.collection("users").doc(uid).collection("people").snapshots().listen((snapshot) {
      _people = snapshot.docs.map((doc) => Person.fromMap(doc.id, doc.data())).toList();
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

  Future<Person> addPerson(String name) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");
    final docRef = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("people")
        .add({"name": name});
    return Person(id: docRef.id, name: name);
  }

  List<Tag> searchTags(String query) {
    if (query.isEmpty) return [];
    return _tags
        .where((tag) => tag.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
