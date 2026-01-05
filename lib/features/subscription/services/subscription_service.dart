import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wallzy/features/subscription/models/due_subscription.dart';
import 'package:wallzy/features/subscription/models/subscription.dart';
import 'package:wallzy/features/subscription/services/subscription_info.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:wallzy/firebase_options.dart';

class SubscriptionService {
  static const dueSubscriptionTask = "dueSubscriptionTask";
  static const _prefsKey = 'due_subscription_suggestions';
  static const _notifiedPrefsKey = 'notified_subscriptions_log';

  static Future<void> checkAndNotifyDueSubscriptions() async {
    // Must be initialized in the background isolate
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Timezone for background isolate
    tz.initializeTimeZones();
    final String rawTimezone = (await FlutterTimezone.getLocalTimezone())
        .toString();
    final String timeZoneName = rawTimezone.contains('(')
        ? rawTimezone.split('(')[1].split(',')[0]
        : rawTimezone;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    final prefs = await SharedPreferences.getInstance();
    final firestore = FirebaseFirestore.instance;

    final uid = prefs.getString('last_user_id');
    if (uid == null) {
      debugPrint('BACKGROUND JOB: No user ID found. Exiting.');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Fetch all active subscriptions
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('subscriptions')
        .where('isActive', isEqualTo: true)
        .get();

    final allSubscriptions = snapshot.docs
        .map((doc) => Subscription.fromMap(doc.data()))
        .toList();

    final List<DueSubscription> newSuggestions = [];
    final batch = firestore.batch();
    final List<String> newlyNotifiedLogs = [];

    for (final subscription in allSubscriptions) {
      if (subscription.pauseState ==
          SubscriptionPauseState.pausedIndefinitely) {
        continue;
      }
      if (subscription.creationMode == SubscriptionCreationMode.automatic) {
        continue; // Skip auto-created ones for now
      }

      // 2. Determine the date to check against based on notification settings
      DateTime checkDate = subscription.nextDueDate;
      switch (subscription.notificationTiming) {
        case SubscriptionNotificationTiming.oneDayBefore:
          checkDate = checkDate.subtract(const Duration(days: 1));
          break;
        case SubscriptionNotificationTiming.twoDaysBefore:
          checkDate = checkDate.subtract(const Duration(days: 2));
          break;
        case SubscriptionNotificationTiming.oneWeekBefore:
          checkDate = checkDate.subtract(const Duration(days: 7));
          break;
        case SubscriptionNotificationTiming.onDueDate:
          break; // No change
      }

      final effectiveDueDate = DateTime(
        checkDate.year,
        checkDate.month,
        checkDate.day,
      );

      // 3. Check if the subscription is due for notification
      if (!effectiveDueDate.isAfter(today)) {
        // 4. Check if we've already notified for this specific original due date
        final notificationLogKey =
            '${subscription.id}_${DateFormat('yyyy-MM-dd').format(subscription.nextDueDate)}';
        final alreadyNotified = (prefs.getStringList(_notifiedPrefsKey) ?? [])
            .contains(notificationLogKey);

        if (alreadyNotified) continue;

        debugPrint(
          'BACKGROUND JOB: Subscription "${subscription.name}" is due for notification.',
        );

        // 5. Create a suggestion
        final suggestion = DueSubscription(
          id: const Uuid().v4(),
          subscriptionName: subscription.name,
          averageAmount: subscription.amount, // Use the defined amount
          lastCategory: subscription.category,
          lastPaymentMethod: subscription.paymentMethod,
          dueDate: subscription.nextDueDate,
          frequency: subscription.frequency,
        );
        newSuggestions.add(suggestion);
        newlyNotifiedLogs.add(notificationLogKey);

        // 6. Show notification
        await _showDueSubscriptionNotification(suggestion);

        // 7. Calculate the next due date and update the single subscription document
        final newNextDueDate = _calculateNextDueDate(
          subscription.nextDueDate,
          subscription.frequency,
          recurrenceDay: subscription.recurrenceDay,
          recurrenceMonth: subscription.recurrenceMonth,
        );
        final newPauseState =
            subscription.pauseState == SubscriptionPauseState.pausedUntilNext
            ? SubscriptionPauseState.active
            : subscription.pauseState;

        final docRef = firestore
            .collection('users')
            .doc(uid)
            .collection('subscriptions')
            .doc(subscription.id);
        batch.update(docRef, {
          'nextDueDate': newNextDueDate.toIso8601String(),
          'pauseState': newPauseState.name,
        });

        // Schedule notification for the NEXT cycle
        // Construct the updated subscription object to schedule
        final updatedSubscription = subscription.copyWith(
          nextDueDate: newNextDueDate,
          pauseState: newPauseState,
        );
        await scheduleSubscriptionNotification(updatedSubscription);
      }
    }

    if (newSuggestions.isNotEmpty) {
      // Save new suggestions to local storage
      final existingJson = prefs.getString(_prefsKey) ?? '[]';
      final List<dynamic> existingList = jsonDecode(existingJson);
      final allSuggestions = [
        ...existingList,
        ...newSuggestions.map((s) => s.toMap()),
      ];
      await prefs.setString(_prefsKey, jsonEncode(allSuggestions));

      // Save notification log
      final existingLogs = prefs.getStringList(_notifiedPrefsKey) ?? [];
      await prefs.setStringList(_notifiedPrefsKey, [
        ...existingLogs,
        ...newlyNotifiedLogs,
      ]);

      // Commit Firestore updates
      await batch.commit();
      debugPrint(
        'BACKGROUND JOB: Found ${newSuggestions.length} due subscriptions. Updated Firestore.',
      );
    } else {
      debugPrint('BACKGROUND JOB: No new due subscriptions found.');
    }
  }

  static DateTime _calculateNextDueDate(
    DateTime currentDueDate,
    SubscriptionFrequency frequency, {
    int? recurrenceDay,
    int? recurrenceMonth,
  }) {
    DateTime nextDate;
    switch (frequency) {
      case SubscriptionFrequency.daily:
        nextDate = currentDueDate.add(const Duration(days: 1));
        break;
      case SubscriptionFrequency.weekly:
        nextDate = currentDueDate.add(const Duration(days: 7));
        break;
      case SubscriptionFrequency.monthly:
        // Naive add
        nextDate = DateTime(
          currentDueDate.year,
          currentDueDate.month + 1,
          currentDueDate.day,
        );
        // Correct using recurrenceDay if present
        if (recurrenceDay != null) {
          final targetMonth = nextDate; // already +1 month
          final lastDayOfTargetMonth = DateTime(
            targetMonth.year,
            targetMonth.month + 1,
            0,
          ).day;
          final dayToUse = recurrenceDay > lastDayOfTargetMonth
              ? lastDayOfTargetMonth
              : recurrenceDay;
          nextDate = DateTime(targetMonth.year, targetMonth.month, dayToUse);
        }
        break;
      case SubscriptionFrequency.quarterly:
        // Add 3 months
        nextDate = DateTime(
          currentDueDate.year,
          currentDueDate.month + 3,
          currentDueDate.day,
        );
        if (recurrenceDay != null) {
          final targetMonth = nextDate;
          final lastDayOfTargetMonth = DateTime(
            targetMonth.year,
            targetMonth.month + 1,
            0,
          ).day;
          final dayToUse = recurrenceDay > lastDayOfTargetMonth
              ? lastDayOfTargetMonth
              : recurrenceDay;
          nextDate = DateTime(targetMonth.year, targetMonth.month, dayToUse);
        }
        break;
      case SubscriptionFrequency.yearly:
        // Add 1 year
        nextDate = DateTime(
          currentDueDate.year + 1,
          currentDueDate.month,
          currentDueDate.day,
        );
        if (recurrenceMonth != null && recurrenceDay != null) {
          // Force strict month/day if possible (e.g. Feb 29 -> Feb 28 next year)
          // But usually just adding year handles it?
          // DateTime(2024, 2, 29).year + 1 -> 2025-02-28 handling
          // Dart DateTime(2025, 2, 29) -> March 1. We might want Feb 28.
          final targetYear = nextDate.year;
          final targetMonth = recurrenceMonth;
          final lastDayOfTargetMonth = DateTime(
            targetYear,
            targetMonth + 1,
            0,
          ).day;
          final dayToUse = recurrenceDay > lastDayOfTargetMonth
              ? lastDayOfTargetMonth
              : recurrenceDay;
          nextDate = DateTime(targetYear, targetMonth, dayToUse);
        }
        break;
    }
    return nextDate;
  }

  static Future<void> _showDueSubscriptionNotification(
    DueSubscription suggestion,
  ) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'due_subscriptions_channel',
      'Due Subscriptions',
      channelDescription: 'Notifications for due subscription payments.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    final title = 'Subscription Due: ${suggestion.subscriptionName}';
    final body =
        'Did you pay ~₹${suggestion.averageAmount.toStringAsFixed(0)}? Tap to add.';

    final notificationId = suggestion.id.hashCode;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(suggestion.toMap()),
    );
  }

  static Future<void> scheduleSubscriptionNotification(
    Subscription subscription,
  ) async {
    if (subscription.pauseState != SubscriptionPauseState.active) return;
    if (subscription.notificationTiming ==
        SubscriptionNotificationTiming.onDueDate) {
      // If "on due date" serves as "no reminder" or "remind me on that day",
      // typically users want a reminder on the day of payment.
    }

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Determine reminder offset
    int daysBefore = 0;
    switch (subscription.notificationTiming) {
      case SubscriptionNotificationTiming.oneDayBefore:
        daysBefore = 1;
        break;
      case SubscriptionNotificationTiming.twoDaysBefore:
        daysBefore = 2;
        break;
      case SubscriptionNotificationTiming.oneWeekBefore:
        daysBefore = 7;
        break;
      case SubscriptionNotificationTiming.onDueDate:
        daysBefore = 0;
        break;
    }

    // Calculate Scheduled Date (9:00 AM)
    final dueDate = subscription.nextDueDate;
    final reminderDate = dueDate.subtract(Duration(days: daysBefore));
    final scheduledDate = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
      0,
    ); // 9:00 AM

    // Check if date is in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      // Don't schedule for past dates
      return;
    }

    // Convert to TZDateTime
    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'subscription_reminders',
      'Subscription Reminders',
      channelDescription: 'Reminders for upcoming subscription payments.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        subscription.id.hashCode,
        'Upcoming Payment: ${subscription.name}',
        '₹${subscription.amount.toStringAsFixed(0)} is due on ${DateFormat('MMM d').format(subscription.nextDueDate)}',
        tzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: subscription.id,
      );
    } catch (e) {
      debugPrint('Exact alarm scheduling failed: $e. Falling back to inexact.');
      await flutterLocalNotificationsPlugin.zonedSchedule(
        subscription.id.hashCode,
        'Upcoming Payment: ${subscription.name}',
        '₹${subscription.amount.toStringAsFixed(0)} is due on ${DateFormat('MMM d').format(subscription.nextDueDate)}',
        tzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: subscription.id,
      );
    }
  }

  static Future<void> cancelSubscriptionNotification(
    Subscription subscription,
  ) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancel(subscription.id.hashCode);
  }
}
