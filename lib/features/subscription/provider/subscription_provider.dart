import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wallzy/features/auth/provider/auth_provider.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/subscription/services/subscription_service.dart';

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
          _subscriptions = snapshot.docs
              .map((doc) => Subscription.fromMap(doc.data()))
              .toList();
          notifyListeners();
        });
  }

  Future<void> addSubscription(Subscription subscription) async {
    final user = authProvider.user;
    if (user == null) return;
    // Optimistic Update
    _subscriptions.add(subscription);
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(subscription.id)
          .set(subscription.toMap());
    } catch (e) {
      // Rollback on failure
      _subscriptions.removeWhere((s) => s.id == subscription.id);
      notifyListeners();
      rethrow;
    }

    // Schedule notification (Non-blocking / Fire-and-forget logic safe)
    // We await it here but wrap in try-catch so it doesn't crash the UI flow if fails
    try {
      await SubscriptionService.scheduleSubscriptionNotification(subscription);
    } catch (e) {
      debugPrint("Failed to schedule notification: $e");
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    final user = authProvider.user;
    if (user == null) return;
    // Optimistic Update
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    Subscription? oldSubscription;
    if (index != -1) {
      oldSubscription = _subscriptions[index];
      _subscriptions[index] = subscription;
      notifyListeners();
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(subscription.id)
          .update(subscription.toMap());
    } catch (e) {
      // Rollback
      if (oldSubscription != null && index != -1) {
        _subscriptions[index] = oldSubscription;
        notifyListeners();
      }
      rethrow;
    }

    // Reschedule (Non-blocking)
    try {
      await SubscriptionService.cancelSubscriptionNotification(subscription);
      await SubscriptionService.scheduleSubscriptionNotification(subscription);
    } catch (e) {
      debugPrint("Failed to reschedule notification: $e");
    }
  }

  // This is a soft delete.
  Future<void> archiveSubscription(String subscriptionInfo) async {
    final user = authProvider.user;
    if (user == null) return;
    // Optimistic Update
    final index = _subscriptions.indexWhere((s) => s.id == subscriptionInfo);
    Subscription? oldSubscription;
    if (index != -1) {
      oldSubscription = _subscriptions[index];
      // Instead of removing, we mark as inactive if we were just filtering.
      // But archive implies we don't want to see it in active list.
      // Since getter filters by isActive, we just update the field.
      final updated = _subscriptions[index].copyWith(isActive: false);
      _subscriptions[index] = updated;
      notifyListeners();
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(subscriptionInfo)
          .update({'isActive': false});
    } catch (e) {
      // Rollback
      if (oldSubscription != null && index != -1) {
        _subscriptions[index] = oldSubscription;
        notifyListeners();
      }
      rethrow;
    }

    // Cancel notification (Non-blocking)
    try {
      final dummySub = Subscription(
        id: subscriptionInfo,
        name: '',
        amount: 0,
        category: '',
        paymentMethod: '',
        frequency: SubscriptionFrequency.monthly,
        nextDueDate: DateTime.now(),
      );
      await SubscriptionService.cancelSubscriptionNotification(dummySub);
    } catch (e) {
      debugPrint("Failed to cancel notification: $e");
    }
  }
}
