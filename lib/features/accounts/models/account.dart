import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String bankName;
  final String accountNumber; // Last 4 digits
  final String? cardNumber; // Last 4 digits of debit card (Optional)
  final String accountHolderName;
  final bool isPrimary;
  final String userId;
  final String accountType;
  final double? creditLimit;
  final int? billingCycleDay;

  Account({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    this.cardNumber,
    required this.accountHolderName,
    this.isPrimary = false,
    required this.userId,
    this.accountType = 'debit',
    this.creditLimit,
    this.billingCycleDay,
  });

  Account copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? cardNumber,
    String? accountHolderName,
    bool? isPrimary,
    String? userId,
    String? accountType,
    double? creditLimit,
    int? billingCycleDay,
  }) {
    return Account(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      cardNumber: cardNumber ?? this.cardNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isPrimary: isPrimary ?? this.isPrimary,
      userId: userId ?? this.userId,
      accountType: accountType ?? this.accountType,
      creditLimit: creditLimit ?? this.creditLimit,
      billingCycleDay: billingCycleDay ?? this.billingCycleDay,
    );
  }

  // The userId is now passed in, as it's part of the document path in Firestore.
  factory Account.fromFirestore(
    DocumentSnapshot doc, {
    required String userId,
  }) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Account(
      id: doc.id,
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      cardNumber: data['cardNumber'],
      accountHolderName: data['accountHolderName'] ?? '',
      isPrimary: data['isPrimary'] ?? false,
      userId: userId,
      accountType: data['accountType'] ?? 'debit',
      creditLimit: data['creditLimit']?.toDouble() ?? 0.0,
      billingCycleDay: data['billingCycleDay']?.toInt() ?? 1,
    );
  }

  // The userId is no longer stored in the document itself.
  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'cardNumber': cardNumber,
      'accountHolderName': accountHolderName,
      'isPrimary': isPrimary,
      'accountType': accountType,
      'creditLimit': creditLimit,
      'billingCycleDay': billingCycleDay,
    };
  }

  // For display purposes
  String get displayName =>
      '$bankName ${accountNumber != '' ? '·' : ''} $accountNumber';
}
