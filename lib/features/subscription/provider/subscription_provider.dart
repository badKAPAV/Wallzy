import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';

class SubscriptionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider authProvider;
  StreamSubscription? _subscriptionStream;

  List<Subscription> _subscriptions = [];
  bool _isLoading = false;

  List<Subscription> get subscriptions =>
      _subscriptions.where((s) => s.isActive).toList();
  bool get isLoading => _isLoading;

  SubscriptionProvider({required this.authProvider}) {
    _listenToSubscriptions();
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    authProvider = newAuthProvider;
    _listenToSubscriptions();
  }

  @override
  void dispose() {
    _subscriptionStream?.cancel();
    super.dispose();
  }

  void _listenToSubscriptions() {
    _subscriptionStream?.cancel();
    final user = authProvider.user;
    if (user == null) {
      _subscriptions = [];
      notifyListeners();
      return;
    }

    _subscriptionStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .snapshots()
        .listen((snapshot) {
      _subscriptions =
          snapshot.docs.map((doc) => Subscription.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> addSubscription(Subscription subscription) async {
    final user = authProvider.user;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(subscription.id)
        .set(subscription.toMap());
  }

  Future<void> updateSubscription(Subscription subscription) async {
    final user = authProvider.user;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(subscription.id)
        .update(subscription.toMap());
  }

  // This is a soft delete.
  Future<void> archiveSubscription(String subscriptionInfo) async {
    final user = authProvider.user;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(subscriptionInfo)
        .update({'isActive': false});
  }
}