import 'package:flutter/material.dart';
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';

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
  });

  factory TransactionModel.fromMap(Map<String, dynamic> data) {
    return TransactionModel(
      category: data['category'] ?? 'others',
      transactionId: data['transactionId'] ?? '',
      type: data['type'] ?? 'expense',
      amount: (data['amount'] ?? 0).toDouble(),
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      description: data['description'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      people: (data['people'] as List<dynamic>? ?? [])
          .map((person) => Person(
                id: person['id'] ?? '',
                name: person['name'] ?? '',
              ))
          .toList(),
      tags: (data['tags'] as List<dynamic>? ?? [])
          .map((tag) => Tag(
                id: tag['id'] ?? '',
                name: tag['name'] ?? '',
              ))
          .toList(),
      currency: data['currency'] ?? 'USD',
      subscriptionId: data['subscriptionId'],
      accountId: data['accountId'],
      purchaseType: data['purchaseType'] ?? 'debit',
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
      'people': people?.map((person) => person.toMap()).toList() ?? [],
      'currency': currency,
      'subscriptionId': subscriptionId,
      'accountId': accountId,
      'purchaseType': purchaseType,
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
      subscriptionId:
          subscriptionId != null ? subscriptionId() : this.subscriptionId,
      accountId: accountId != null ? accountId() : this.accountId,
      purchaseType: purchaseType ?? this.purchaseType,
    );
  }
}
