package com.kapav.wallzy

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    // 1. CHANNEL CONSTANTS
    private val SMS_CHANNEL = "com.kapav.wallzy/sms"          // LEGACY (Your existing code depends on this)
    private val SETTINGS_CHANNEL = "com.kapav.wallzy/settings" // NEW (Only for rule updates)

    private var smsMethodChannel: MethodChannel? = null
    private var cachedSmsData: Map<String, Any?>? = null

    // BroadcastReceiver for live SMS updates (uses SMS_CHANNEL)
    private val newSmsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.kapav.wallzy.NEW_PENDING_SMS_ACTION") {
                Log.d("MainActivity", "New pending SMS broadcast received. Notifying Flutter.")
                smsMethodChannel?.invokeMethod("newPendingSmsAvailable", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)

        val filter = IntentFilter("com.kapav.wallzy.NEW_PENDING_SMS_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(newSmsReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(newSmsReceiver, filter)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(newSmsReceiver)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- CHANNEL 1: SMS (The "Workhorse") ---
        smsMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsMethodChannel?.setMethodCallHandler { call, result ->
            // Route all existing logic here
            handleSmsChannelMethod(call.method, call, result)
        }

        // --- CHANNEL 2: SETTINGS (The "Updater") ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateSmsRules") {
                val jsonContent = call.argument<String>("json")
                if (jsonContent != null) {
                    PatternRepository.saveNewRules(context, jsonContent)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Json content was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Extracted your huge "when" block here to keep things tidy
    private fun handleSmsChannelMethod(method: String, call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (method) {
            "getPendingSmsTransactions" -> {
                val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
                val jsonString = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")
                result.success(jsonString)
            }
            "removePendingSmsTransaction" -> {
                val id = call.argument<String>("id")
                if (id != null) {
                    removePendingTransaction(id)
                    result.success(true)
                } else {
                    result.error("INVALID_ARG", "Transaction ID is null", null)
                }
            }
            "restorePendingSmsTransaction" -> {
                val transactionJson = call.argument<String>("transaction")
                if (transactionJson != null) {
                    restorePendingTransaction(transactionJson)
                    result.success(true)
                } else {
                    result.error("INVALID_ARG", "Transaction JSON is null", null)
                }
            }
            "cancelNotification" -> {
                val notificationId = call.argument<Int>("notificationId")
                if (notificationId != null && notificationId != -1) {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(notificationId)
                    result.success(true)
                } else {
                    result.error("INVALID_ARG", "Notification ID is invalid", null)
                }
            }
            "removeAllPendingSmsTransactions" -> {
                removeAllPendingTransactions()
                result.success(true)
            }
            "getLaunchData" -> {
                cachedSmsData?.let {
                    Log.d("MainActivity", "getLaunchData: Sending cached data to Flutter: $it")
                    val json = JSONObject(it).toString()
                    result.success(json)
                    cachedSmsData = null
                } ?: run {
                    result.success(null)
                }
            }
            "isNotificationListenerEnabled" -> {
                result.success(isNotificationServiceEnabled(this))
            }
            "openNotificationListenerSettings" -> {
                val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                startActivity(intent)
                result.success(true)
            }
            "openAppInfo" -> {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not open app info", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isNotificationServiceEnabled(context: Context): Boolean {
        val flat = android.provider.Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return flat?.contains(context.packageName) == true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "ADD_TRANSACTION_FROM_SMS") {
            val notificationId = intent.getIntExtra("notification_id", -1)
            if (notificationId != -1) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notificationId)
            }

            val transactionJson = intent.getStringExtra("wallzy.transaction.json") ?: return

            val data = try {
                val jsonObject = org.json.JSONObject(transactionJson)
                val map = mutableMapOf<String, Any?>()
                val keys = jsonObject.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    map[key] = if (jsonObject.isNull(key)) null else jsonObject.get(key)
                }
                map
            } catch (e: org.json.JSONException) {
                Log.e("MainActivity", "Failed to parse JSON", e)
                null
            }

            if (data == null) return
            
            if (smsMethodChannel != null) {
                 smsMethodChannel?.invokeMethod("onSmsReceived", data)
            } else {
                cachedSmsData = data
            }
        }
    }

    private fun removePendingTransaction(id: String) {
        val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        try {
            val jsonArray = JSONArray(existingJson)
            val newList = JSONArray()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                if (obj.getString("id") == id) {
                    val notificationId = obj.optInt("notificationId", -1)
                    if (notificationId != -1) {
                        notificationManager.cancel(notificationId)
                    }
                } else {
                    newList.put(obj)
                }
            }
            prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, newList.toString()).apply()
        } catch (e: JSONException) {
            Log.e("MainActivity", "Error removing pending transaction", e)
        }
    }

    private fun removeAllPendingTransactions() {
        val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        try {
            val jsonArray = JSONArray(existingJson)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val notificationId = obj.optInt("notificationId", -1)
                if (notificationId != -1) {
                    notificationManager.cancel(notificationId)
                }
            }
        } catch (e: JSONException) {
            Log.e("MainActivity", "Error parsing pending transactions", e)
        }
        prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]").apply()
    }

    private fun restorePendingTransaction(transactionJson: String) {
        val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")
        try {
            val jsonArray = JSONArray(existingJson)
            val newObj = JSONObject(transactionJson)
            jsonArray.put(newObj)
            prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, jsonArray.toString()).apply()
        } catch (e: JSONException) {
            Log.e("MainActivity", "Error restoring pending transaction", e)
        }
    }
}