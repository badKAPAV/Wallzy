import 'package:cloud_firestore/cloud_firestore.dart';

class SmsFeedbackModel {
  final String id;
  final String userId;
  final String bankName;
  final String senderId;
  final String rawSms;
  final String transactionType;
  final Map<String, dynamic> taggedData;
  final String status;
  final DateTime timestamp;

  SmsFeedbackModel({
    required this.id,
    required this.userId,
    required this.bankName,
    required this.senderId,
    required this.rawSms,
    required this.transactionType,
    required this.taggedData,
    required this.status,
    required this.timestamp,
  });

  factory SmsFeedbackModel.fromMap(String id, Map<String, dynamic> map) {
    return SmsFeedbackModel(
      id: id,
      userId: map['userId'] ?? '',
      bankName: map['bankName'] ?? '',
      senderId: map['senderId'] ?? '',
      rawSms: map['rawSms'] ?? '',
      transactionType: map['transactionType'] ?? '',
      taggedData: Map<String, dynamic>.from(map['taggedData'] ?? {}),
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bankName': bankName,
      'senderId': senderId,
      'rawSms': rawSms,
      'transactionType': transactionType,
      'taggedData': taggedData,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
