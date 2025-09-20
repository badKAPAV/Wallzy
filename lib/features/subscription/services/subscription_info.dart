import 'package:flutter/foundation.dart';

enum SubscriptionFrequency {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly,
}

extension SubscriptionFrequencyExtension on SubscriptionFrequency {
  String get displayName {
    switch (this) {
      case SubscriptionFrequency.daily:
        return 'Daily';
      case SubscriptionFrequency.weekly:
        return 'Weekly';
      case SubscriptionFrequency.monthly:
        return 'Monthly';
      case SubscriptionFrequency.quarterly:
        return 'Quarterly';
      case SubscriptionFrequency.yearly:
        return 'Yearly';
    }
  }
}

enum SubscriptionPauseState {
  active,
  pausedUntilNext, // Paused for one cycle
  pausedIndefinitely, // Paused until manually resumed
}

enum SubscriptionCreationMode {
  automatic, // "Create transaction automatically on selected date"
  manual, // "Link transaction manually"
}

extension SubscriptionCreationModeExtension on SubscriptionCreationMode {
  String get displayName {
    switch (this) {
      case SubscriptionCreationMode.automatic:
        return 'Create transaction automatically';
      case SubscriptionCreationMode.manual:
        return 'Link transaction manually';
    }
  }
}

enum SubscriptionNotificationTiming {
  onDueDate,
  oneDayBefore,
  twoDaysBefore,
  oneWeekBefore,
}

extension SubscriptionNotificationTimingExtension on SubscriptionNotificationTiming {
  String get displayName {
    switch (this) {
      case SubscriptionNotificationTiming.onDueDate:
        return 'On due date';
      case SubscriptionNotificationTiming.oneDayBefore:
        return '1 day before';
      case SubscriptionNotificationTiming.twoDaysBefore:
        return '2 days before';
      case SubscriptionNotificationTiming.oneWeekBefore:
        return '1 week before';
    }
  }
}

@immutable
class SubscriptionInfo {
  final SubscriptionFrequency frequency;
  final DateTime nextDueDate;
  // This can be used later for auto-creation of transactions
  final bool isAutoPay;
  // New field to track the pause state of the subscription.
  final SubscriptionPauseState pauseState;

  const SubscriptionInfo({
    required this.frequency,
    required this.nextDueDate,
    this.isAutoPay = false,
    this.pauseState = SubscriptionPauseState.active,
  });

  SubscriptionInfo copyWith({
    SubscriptionFrequency? frequency,
    DateTime? nextDueDate,
    bool? isAutoPay,
    SubscriptionPauseState? pauseState,
  }) {
    return SubscriptionInfo(
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isAutoPay: isAutoPay ?? this.isAutoPay,
      pauseState: pauseState ?? this.pauseState,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.name,
      'nextDueDate': nextDueDate.toIso8601String(),
      'isAutoPay': isAutoPay,
      'pauseState': pauseState.name,
    };
  }

  factory SubscriptionInfo.fromMap(Map<String, dynamic> map) {
    return SubscriptionInfo(
      frequency: SubscriptionFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => SubscriptionFrequency.monthly,
      ),
      nextDueDate: DateTime.parse(map['nextDueDate']),
      isAutoPay: map['isAutoPay'] ?? false,
      pauseState: SubscriptionPauseState.values.firstWhere(
        (e) => e.name == map['pauseState'],
        orElse: () => SubscriptionPauseState.active,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SubscriptionInfo &&
        other.frequency == frequency &&
        other.nextDueDate == nextDueDate &&
        other.isAutoPay == isAutoPay &&
        other.pauseState == pauseState;
  }

  @override
  int get hashCode =>
      frequency.hashCode ^ nextDueDate.hashCode ^ isAutoPay.hashCode ^ pauseState.hashCode;
}