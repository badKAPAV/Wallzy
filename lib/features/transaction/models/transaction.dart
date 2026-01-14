import 'package:flutter/material.dart';
import 'package:wallzy/features/people/models/person.dart';
import 'package:wallzy/features/tag/models/tag.dart';

class TransactionModel {
  final String transactionId;
  final String type;
  final double amount;
  final DateTime timestamp;
  final String description;
  final String paymentMethod;
  final List<Tag>? tags;
  final List<Person>? people;
  final String currency;
  final String category;
  final String? subscriptionId;
  final String? accountId;
  final String purchaseType;
  final String? transferGroupId;
  final bool? isCredit;
  final DateTime? reminderDate;
  final String? receiptUrl;

  TransactionModel({
    this.people,
    required this.category,
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.description,
    required this.paymentMethod,
    this.tags,
    required this.currency,
    this.subscriptionId,
    this.accountId,
    this.purchaseType = 'debit',
    this.transferGroupId,
    this.isCredit,
    this.reminderDate,
    this.receiptUrl,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> data) {
    return TransactionModel(
      category: data['category'] ?? 'others',
      transactionId: data['transactionId'] ?? '',
      type: data['type'] ?? 'expense',
      amount: (data['amount'] ?? 0).toDouble(),
      timestamp: DateTime.parse(
        data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      description: data['description'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      people: (data['people'] as List<dynamic>? ?? [])
          .where((person) => person != null)
          .map(
            (person) => Person(
              id: person['id'] ?? '',
              fullName: person['fullName'] ?? '',
            ),
          )
          .toList(),
      tags: (data['tags'] as List<dynamic>? ?? [])
          .where((tag) => tag != null)
          .map((tag) => Tag.fromMap(tag['id'] ?? '', tag))
          .toList(),
      currency: data['currency'] ?? 'USD',
      subscriptionId: data['subscriptionId'],
      accountId: data['accountId'],
      purchaseType: data['purchaseType'] ?? 'debit',
      transferGroupId: data['transferGroupId'],
      isCredit: data['isCredit'],
      reminderDate: data['reminderDate'] != null
          ? DateTime.parse(data['reminderDate'])
          : null,
      receiptUrl: data['receiptUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'transactionId': transactionId,
      'type': type,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'paymentMethod': paymentMethod,
      'tags': tags?.map((tag) => tag.toMap()).toList() ?? [],
      'people': people?.map((person) => person.toFirestore()).toList() ?? [],
      'currency': currency,
      'subscriptionId': subscriptionId,
      'accountId': accountId,
      'purchaseType': purchaseType,
      'transferGroupId': transferGroupId,
      'isCredit': isCredit,
      'reminderDate': reminderDate?.toIso8601String(),
      'receiptUrl': receiptUrl,
    };
  }
}

extension TransactionCopyWith on TransactionModel {
  TransactionModel copyWith({
    List<Person>? people,
    String? category,
    String? transactionId,
    String? type,
    double? amount,
    DateTime? timestamp,
    String? description,
    String? paymentMethod,
    List<Tag>? tags,
    String? currency,
    ValueGetter<String?>? subscriptionId,
    ValueGetter<String?>? accountId,
    String? purchaseType,
    String? transferGroupId,
    bool? isCredit,
    DateTime? reminderDate,
    ValueGetter<String?>? receiptUrl,
  }) {
    return TransactionModel(
      people: people ?? this.people,
      category: category ?? this.category,
      transactionId: transactionId ?? this.transactionId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tags: tags ?? this.tags,
      currency: currency ?? this.currency,
      subscriptionId: subscriptionId != null
          ? subscriptionId()
          : this.subscriptionId,
      accountId: accountId != null ? accountId() : this.accountId,
      purchaseType: purchaseType ?? this.purchaseType,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      isCredit: isCredit ?? this.isCredit,
      reminderDate: reminderDate ?? this.reminderDate,
      receiptUrl: receiptUrl != null ? receiptUrl() : this.receiptUrl,
    );
  }
}
