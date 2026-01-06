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
    private val CHANNEL = "com.kapav.wallzy/sms"
    private var methodChannel: MethodChannel? = null
    private var cachedSmsData: Map<String, Any?>? = null

    // NEW: BroadcastReceiver to listen for new SMS events from SmsReceiver
    private val newSmsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.kapav.wallzy.NEW_PENDING_SMS_ACTION") {
                Log.d("MainActivity", "New pending SMS broadcast received. Notifying Flutter.")
                // Use the stored method channel to notify Flutter to refresh its list
                methodChannel?.invokeMethod("newPendingSmsAvailable", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)

        // NEW: Register the receiver to get live updates
        val filter = IntentFilter("com.kapav.wallzy.NEW_PENDING_SMS_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(newSmsReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(newSmsReceiver, filter)
        }
    }

    override fun onDestroy() {
        // NEW: Unregister the receiver to prevent memory leaks
        unregisterReceiver(newSmsReceiver)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Assign to the class property so it can be used by the BroadcastReceiver
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "MethodChannel called: ${call.method}")
            when (call.method) {
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
                        Log.d("MainActivity", "getLaunchData: No cached data to send. VERIFY_BUILD_123")
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
            // Cancel the notification
            val notificationId = intent.getIntExtra("notification_id", -1)
            if (notificationId != -1) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notificationId)
            }

            // NEW: Get the JSON string from the intent
            val transactionJson = intent.getStringExtra("wallzy.transaction.json")

            if (transactionJson == null) {
                Log.e("MainActivity", "handleIntent: transactionJson is null. Cannot proceed.")
                return
            }

            Log.d("MainActivity", "handleIntent: Received transaction JSON: $transactionJson")

            methodChannel?.invokeMethod("onSmsReceived", transactionJson)

            // Parse the JSON string into a map
            val data = try {
                val jsonObject = org.json.JSONObject(transactionJson)
                val map = mutableMapOf<String, Any?>()
                val keys = jsonObject.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    // Handle JSON's null representation
                    map[key] = if (jsonObject.isNull(key)) null else jsonObject.get(key)
                }
                map
            } catch (e: org.json.JSONException) {
                Log.e("MainActivity", "handleIntent: Failed to parse transaction JSON", e)
                null
            }

            if (data == null) return
            
            // If methodChannel is not null, Flutter engine is configured and app is likely running.
            // If it's null, the app is starting, so we must cache the data.
            if (methodChannel != null) {
                 Log.d("MainActivity", "handleIntent (warm start): Pushing SMS data to Flutter.")
                 methodChannel?.invokeMethod("onSmsReceived", data)
            } else {
                Log.d("MainActivity", "handleIntent (cold start): Caching SMS data for Flutter to pull.")
                cachedSmsData = data
            }
        }
    }

    private fun removePendingTransaction(id: String) {
        val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")

        try {
            val jsonArray = JSONArray(existingJson)
            val newList = JSONArray()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                if (obj.getString("id") != id) {
                    newList.put(obj)
                }
            }
            prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, newList.toString()).apply()
            Log.d("MainActivity", "Removed pending transaction with id: $id")
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
            Log.e("MainActivity", "Error parsing pending transactions to cancel notifications", e)
        }

        prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]").apply()
        Log.d("MainActivity", "Removed all pending transactions.")
    }

    private fun restorePendingTransaction(transactionJson: String) {
        val prefs = getSharedPreferences(SmsTransactionParser.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, "[]")

        try {
            val jsonArray = JSONArray(existingJson)
            val newObj = JSONObject(transactionJson)
            jsonArray.put(newObj)
            prefs.edit().putString(SmsTransactionParser.KEY_PENDING_TRANSACTIONS, jsonArray.toString()).apply()
            Log.d("MainActivity", "Restored pending transaction.")
        } catch (e: JSONException) {
            Log.e("MainActivity", "Error restoring pending transaction", e)
        }
    }
}