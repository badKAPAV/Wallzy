import 'package:cloud_firestore/cloud_firestore.dart';

class Person {
  final String id;
  final String fullName;
  final String? email;
  final String? nickname;
  final double youOwe;
  final double owesYou;
  final DateTime? reminderDate;

  Person({
    required this.id,
    required this.fullName,
    this.email,
    this.nickname,
    this.youOwe = 0.0,
    this.owesYou = 0.0,
    this.reminderDate,
  });

  factory Person.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Person(
      id: doc.id,
      fullName: data['fullName'] ?? data['name'] ?? '',
      email: data['email'],
      nickname: data['nickname'],
      youOwe: (data['youOwe'] ?? 0.0).toDouble(),
      owesYou: (data['owesYou'] ?? 0.0).toDouble(),
      reminderDate: data['reminderDate'] != null
          ? (data['reminderDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'nickname': nickname,
      'youOwe': youOwe,
      'owesYou': owesYou,
      'reminderDate': reminderDate != null ? Timestamp.fromDate(reminderDate!) : null,
    };
  }

  Person copyWith({
    String? id,
    String? fullName,
    String? email,
    String? nickname,
    double? youOwe,
    double? owesYou,
    DateTime? reminderDate,
  }) {
    return Person(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      youOwe: youOwe ?? this.youOwe,
      owesYou: owesYou ?? this.owesYou,
      reminderDate: reminderDate ?? this.reminderDate,
    );
  }

  toMap() {}
}
