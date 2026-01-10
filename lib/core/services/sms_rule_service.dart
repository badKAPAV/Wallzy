import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmsRuleService {
  // Must match the CHANNEL name in your MainActivity.kt
  static const MethodChannel _channel = MethodChannel(
    'com.kapav.wallzy/settings',
  );
  static const String _versionKey = 'sms_rules_version';

  /// Call this in your main.dart (e.g., in a provider or init method)
  Future<void> syncRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to 0 so we always try to fetch at least once
      final currentVersion = prefs.getInt(_versionKey) ?? 0;

      debugPrint(
        "🔍 Checking for SMS Rules update (Current v$currentVersion)...",
      );

      // 1. Fetch JSON from Firebase Storage
      // Ensure 'sms_patterns.json' is at the root of your bucket
      final ref = FirebaseStorage.instance.ref().child('sms_patterns.json');

      // Safety Cap: Limit download to 1MB to prevent billing spikes
      final Uint8List? data = await ref.getData(1024 * 1024);
      if (data == null) {
        debugPrint("⚠️ SMS Rules file not found in Storage.");
        return;
      }

      // 2. Parse & Check Version
      final jsonString = utf8.decode(data);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final int newVersion = jsonMap['version'] ?? 0;

      if (newVersion > currentVersion) {
        debugPrint(
          "⬇️ Found new SMS Rules (v$newVersion). Updating Native Engine...",
        );

        // 3. Send to Android Native Layer
        // This calls MainActivity -> PatternRepository.saveNewRules()
        final bool success = await _channel.invokeMethod('updateSmsRules', {
          'json': jsonString,
        });

        if (success) {
          await prefs.setInt(_versionKey, newVersion);
          debugPrint("✅ SMS Rules updated successfully to v$newVersion.");
        } else {
          debugPrint("❌ Native layer failed to save rules.");
        }
      } else {
        debugPrint("✅ SMS Rules are up to date.");
      }
    } catch (e) {
      // It's normal to fail if offline. Fail silently.
      debugPrint("⚠️ SMS Sync skipped: $e");
    }
  }
}
