import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wallzy/features/feedback/models/sms_feedback_model.dart';

class SmsFeedbackProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SmsFeedbackModel> _smsRequests = [];
  List<SmsFeedbackModel> get smsRequests => _smsRequests;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> submitSmsTemplate({
    required String userId,
    required String bankName,
    required String senderId,
    required String rawSms,
    required String transactionType, // 'income' or 'expense'
    required String paymentMethod,
    required Map<String, dynamic>
    taggedData, // { 'amount': '500', 'payee': 'Zomato' }
  }) async {
    // 1. Internet Check
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception("No Internet Connection");
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 2. Prepare Data Payload
      final data = {
        'userId': userId,
        'bankName': bankName,
        'senderId': senderId.toUpperCase(),
        'rawSms': rawSms,
        'transactionType': transactionType,
        'paymentMethod': paymentMethod,
        'taggedData': taggedData,
        'status': 'pending', // For admin to filter
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0', // Useful for debugging
      };

      // 3. Submit to NEW Collection
      await _firestore.collection('sms_parsing_requests').add(data);
      // 4. Update local list and refresh
      await fetchUserSmsRequests(userId);
    } catch (e) {
      debugPrint("Error submitting SMS template: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserSmsRequests(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('sms_parsing_requests')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      _smsRequests = snapshot.docs
          .map((doc) => SmsFeedbackModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint("Error fetching SMS requests: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
