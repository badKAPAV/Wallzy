package com.example.wallzy

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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.wallzy/sms"
    private var methodChannel: MethodChannel? = null
    private var cachedSmsData: Map<String, Any?>? = null

    // NEW: BroadcastReceiver to listen for new SMS events from SmsReceiver
    private val newSmsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.wallzy.NEW_PENDING_SMS_ACTION") {
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
        val filter = IntentFilter("com.example.wallzy.NEW_PENDING_SMS_ACTION")
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
            when (call.method) {
                "getPendingSmsTransactions" -> {
                    val prefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    val jsonString = prefs.getString(SmsReceiver.KEY_PENDING_TRANSACTIONS, "[]")
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
            }
        }

        cachedSmsData?.let {
            methodChannel?.invokeMethod("onSmsReceived", it)
            cachedSmsData = null
        }
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

            val id = intent.getStringExtra("transaction_id")
            // NEW: Remove from pending list immediately when notification is tapped.
            if (id != null) {
                removePendingTransaction(id)
            }

            val type = intent.getStringExtra("transaction_type")
            val amount = intent.getDoubleExtra("transaction_amount", 0.0)
            val paymentMethod = intent.getStringExtra("payment_method")
            val bankName = intent.getStringExtra("bank_name")
            val accountNumber = intent.getStringExtra("account_number")
            val payee = intent.getStringExtra("payee")
            val category = intent.getStringExtra("category")

            val data = mapOf(
                "id" to id, "type" to type, "amount" to amount, "paymentMethod" to paymentMethod,
                "bankName" to bankName,
                "accountNumber" to accountNumber,
                "payee" to payee,
                "category" to category
            )
            
            // FIXED: Removed the invalid '.isAttachedToJni' check.
            // A simple null check on the flutterEngine is the correct modern approach.
            if (flutterEngine != null) {
                 methodChannel?.invokeMethod("onSmsReceived", data)
            } else {
                cachedSmsData = data
            }
        }
    }

    private fun removePendingTransaction(id: String) {
        val prefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsReceiver.KEY_PENDING_TRANSACTIONS, "[]")

        try {
            val jsonArray = JSONArray(existingJson)
            val newList = JSONArray()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                if (obj.getString("id") != id) {
                    newList.put(obj)
                }
            }
            prefs.edit().putString(SmsReceiver.KEY_PENDING_TRANSACTIONS, newList.toString()).apply()
            Log.d("MainActivity", "Removed pending transaction with id: $id")
            android.util.Log.d("MainActivity", "Removed pending transaction with id: $id")
        } catch (e: JSONException) {
            Log.e("MainActivity", "Error removing pending transaction", e)
            android.util.Log.e("MainActivity", "Error removing pending transaction", e)
        }
    }

    private fun removeAllPendingTransactions() {
        val prefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(SmsReceiver.KEY_PENDING_TRANSACTIONS, "[]")
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

        prefs.edit().putString(SmsReceiver.KEY_PENDING_TRANSACTIONS, "[]").apply()
        Log.d("MainActivity", "Removed all pending transactions.")
    }
}