import 'package:uuid/uuid.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:wallzy/features/transaction/models/person.dart';
import 'package:wallzy/features/transaction/models/tag.dart';

class Subscription {
  final String id;
  final String name;
  final double amount;
  final String category;
  final String paymentMethod;
  final SubscriptionFrequency frequency;
  final DateTime nextDueDate;
  final SubscriptionCreationMode creationMode;
  final SubscriptionNotificationTiming notificationTiming;
  final SubscriptionPauseState pauseState;
  final List<Tag>? tags;
  final List<Person>? people;
  final bool isActive; // for soft delete

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.frequency,
    required this.nextDueDate,
    this.creationMode = SubscriptionCreationMode.manual,
    this.notificationTiming = SubscriptionNotificationTiming.onDueDate,
    this.pauseState = SubscriptionPauseState.active,
    this.tags,
    this.people,
    this.isActive = true,
  });

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    String? category,
    String? paymentMethod,
    SubscriptionFrequency? frequency,
    DateTime? nextDueDate,
    SubscriptionCreationMode? creationMode,
    SubscriptionNotificationTiming? notificationTiming,
    SubscriptionPauseState? pauseState,
    List<Tag>? tags,
    List<Person>? people,
    bool? isActive,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      creationMode: creationMode ?? this.creationMode,
      notificationTiming: notificationTiming ?? this.notificationTiming,
      pauseState: pauseState ?? this.pauseState,
      tags: tags ?? this.tags,
      people: people ?? this.people,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'frequency': frequency.name,
      'nextDueDate': nextDueDate.toIso8601String(),
      'creationMode': creationMode.name,
      'notificationTiming': notificationTiming.name,
      'pauseState': pauseState.name,
      'tags': tags?.map((x) => x.toMap()).toList(),
      'people': people?.map((x) => x.toMap()).toList(),
      'isActive': isActive,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'Others',
      paymentMethod: map['paymentMethod'] ?? 'Other',
      frequency: SubscriptionFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => SubscriptionFrequency.monthly,
      ),
      nextDueDate: DateTime.parse(map['nextDueDate']),
      creationMode: SubscriptionCreationMode.values.firstWhere(
        (e) => e.name == map['creationMode'],
        orElse: () => SubscriptionCreationMode.manual,
      ),
      notificationTiming: SubscriptionNotificationTiming.values.firstWhere(
        (e) => e.name == map['notificationTiming'],
        orElse: () => SubscriptionNotificationTiming.onDueDate,
      ),
      pauseState: SubscriptionPauseState.values.firstWhere(
        (e) => e.name == map['pauseState'],
        orElse: () => SubscriptionPauseState.active,
      ),
      tags: map['tags'] != null
          ? List<Tag>.from(
              map['tags']?.map((x) => Tag(id: x['id'], name: x['name'])))
          : null,
      people: map['people'] != null
          ? List<Person>.from((map['people'] as List<dynamic>)
              .map((x) => Person(id: x['id'], name: x['name'])))
          : null,
      isActive: map['isActive'] ?? true,
    );
  }
}