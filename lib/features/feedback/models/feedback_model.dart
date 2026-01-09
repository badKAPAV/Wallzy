import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String userId;
  final String title;
  final String topic;
  final double impactRating; // 1.0 to 10.0
  final String stepsToReproduce; // Combined string
  final List<String> imageUrls;
  final String status; // 'pending', 'reviewed', 'resolved'
  final DateTime timestamp;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.topic,
    required this.impactRating,
    required this.stepsToReproduce,
    required this.imageUrls,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'topic': topic,
      'impactRating': impactRating,
      'stepsToReproduce': stepsToReproduce,
      'imageUrls': imageUrls,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory FeedbackModel.fromMap(String id, Map<String, dynamic> map) {
    return FeedbackModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      topic: map['topic'] ?? 'Other',
      impactRating: (map['impactRating'] ?? 0).toDouble(),
      stepsToReproduce: map['stepsToReproduce'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
