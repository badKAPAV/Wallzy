import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String bankName;
  final String accountNumber; // Last 4 digits
  final String accountHolderName;
  final bool isPrimary;
  final String userId;

  Account({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.isPrimary = false,
    required this.userId,
  });

  Account copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    bool? isPrimary,
    String? userId,
  }) {
    return Account(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isPrimary: isPrimary ?? this.isPrimary,
      userId: userId ?? this.userId,
    );
  }

  factory Account.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Account(
      id: doc.id,
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      accountHolderName: data['accountHolderName'] ?? '',
      isPrimary: data['isPrimary'] ?? false,
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'isPrimary': isPrimary,
      'userId': userId,
    };
  }

  // For display purposes
  String get displayName => '$bankName ${accountNumber!='' ? '·' : ''} $accountNumber';
}
