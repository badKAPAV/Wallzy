import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/people/models/person.dart';

class PeopleProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider authProvider;
  StreamSubscription? _peopleSubscription;

  List<Person> _people = [];
  List<Person> get people => _people;

  PeopleProvider({required this.authProvider}) {
    if (authProvider.isLoggedIn) {
      _listenToData();
    }
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    if (authProvider.isLoggedIn) {
      _listenToData();
    } else {
      _people = [];
      _peopleSubscription?.cancel();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _peopleSubscription?.cancel();
    super.dispose();
  }

  void _listenToData() {
    final user = authProvider.user;
    if (user == null) return;
    _listenToPeople(user.uid);
  }

  void _listenToPeople(String uid) {
    _peopleSubscription?.cancel();
    _peopleSubscription = _firestore
        .collection("users")
        .doc(uid)
        .collection("people")
        .snapshots()
        .listen((snapshot) {
          _people = snapshot.docs
              .map((doc) => Person.fromFirestore(doc))
              .toList();
          notifyListeners();
        });
  }

  Future<Person> addPerson(Person person) async {
    final user = authProvider.user;
    if (user == null) throw Exception("User not logged in");

    // Check if person already exists to avoid duplicates by name
    final existing = _people.where(
      (p) =>
          p.fullName.toLowerCase().trim() ==
          person.fullName.toLowerCase().trim(),
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final docRef = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("people")
        .add(person.toFirestore())
        .timeout(const Duration(seconds: 2));
    return person.copyWith(id: docRef.id);
  }

  Future<void> updatePerson(Person person) async {
    final user = authProvider.user;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('people')
        .doc(person.id)
        .update(person.toFirestore())
        .timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  // Getters for PeopleScreen
  double get totalYouOwe => _people.fold(0.0, (sum, p) => sum + p.youOwe);
  double get totalOwesYou => _people.fold(0.0, (sum, p) => sum + p.owesYou);

  List<Person> get youOweList => _people.where((p) => p.youOwe > 0).toList();
  List<Person> get owesYouList => _people.where((p) => p.owesYou > 0).toList();
}
