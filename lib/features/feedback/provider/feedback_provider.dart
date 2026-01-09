import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/feedback/models/feedback_model.dart';

class FeedbackProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<FeedbackModel> _feedbacks = [];
  List<FeedbackModel> get feedbacks => _feedbacks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  // --- Internet Check Helper ---
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _hasInternet = !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint("Connectivity plugin error: $e");
      // Fallback: Assume internet is available if the plugin fails (e.g., MissingPluginException)
      _hasInternet = true;
    }
    notifyListeners();
    return _hasInternet;
  }

  // --- Fetch Feedbacks ---
  Future<void> fetchUserFeedbacks(String userId) async {
    if (!await checkConnectivity()) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('feedbacks')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      _feedbacks = snapshot.docs
          .map((doc) => FeedbackModel.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        debugPrint("CRITICAL: Firestore index missing for feedbacks query.");
        debugPrint(
          "Create it here: https://console.firebase.google.com/v1/r/project/wallet-wallzy/firestore/indexes?create_composite=Ck9wcm9qZWN0cy93YWxsZXQtd2FsbHp5L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9mZWVkYmFja3MvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg",
        );
      } else {
        debugPrint("Firebase error fetching feedbacks: ${e.message}");
      }
    } catch (e) {
      debugPrint("Error fetching feedbacks: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Submit Feedback ---
  Future<void> submitFeedback({
    required String userId,
    required String title,
    required String topic,
    required double impact,
    required String steps,
    required List<File> images,
  }) async {
    if (!await checkConnectivity()) {
      throw Exception("No Internet Connection");
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload Images
      List<String> imageUrls = [];
      for (var image in images) {
        final ref = _storage
            .ref()
            .child('feedback_images')
            .child(const Uuid().v4());
        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // 2. Create Model
      final newFeedback = FeedbackModel(
        id: '', // Firestore generates this
        userId: userId,
        title: title,
        topic: topic,
        impactRating: impact,
        stepsToReproduce: steps,
        imageUrls: imageUrls,
        status: 'pending',
        timestamp: DateTime.now(),
      );

      // 3. Save to Firestore
      await _firestore.collection('feedbacks').add(newFeedback.toMap());

      // 4. Refresh List
      await fetchUserFeedbacks(userId);
    } catch (e) {
      debugPrint("Error submitting feedback: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
