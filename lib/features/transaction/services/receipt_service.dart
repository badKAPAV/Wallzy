import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ReceiptService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Singleton
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  /// Uploads a receipt image to Firebase Storage and returns the download URL.
  ///
  /// Path: users/{userId}/receipts/{transactionId}.png
  Future<String> uploadReceipt({
    required Uint8List imageData,
    required String userId,
    required String transactionId,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('receipts')
          .child('$transactionId.png');

      // Upload raw bytes
      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'transactionId': transactionId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(imageData, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading receipt: $e");
      rethrow;
    }
  }

  /// Deletes a receipt image from Firebase Storage using its URL.
  Future<void> deleteReceipt(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint("Error deleting receipt: $e");
      // Don't rethrow, just log.
      // It's possible the file writes failed but DB didn't, or vice-versa.
    }
  }
}
