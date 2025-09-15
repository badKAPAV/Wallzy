package com.example.wallzy

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Locale
import java.util.regex.Pattern
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME = "SmsPendingTransactions"
        const val KEY_PENDING_TRANSACTIONS = "pending_transactions"
    }
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            messages.forEach { smsMessage ->
                val msgBody = smsMessage.messageBody
                Log.d("SmsReceiver", "Message Received: $msgBody")
                android.util.Log.d("SmsReceiver", "Message Received: $msgBody")
                parseMessageAndNotify(context, msgBody)
            }
        }
    }

    private fun parseMessageAndNotify(context: Context, message: String) {
        // CHANGED: Use the modern, locale-aware lowercase() function
        val lowerCaseMessage = message.lowercase(Locale.getDefault())

        val isCredit = lowerCaseMessage.contains("credited") || lowerCaseMessage.contains("received") || lowerCaseMessage.contains("deposit")
        val isDebit = lowerCaseMessage.contains("debited") || lowerCaseMessage.contains("spent") || lowerCaseMessage.contains("paid") || lowerCaseMessage.contains("sent")

        if (!isCredit && !isDebit) return

        val transactionType = if (isCredit) "income" else "expense"

        // Regex to find amount (handles formats like 1,234.56 or 1234)
        val amountPattern = Pattern.compile("(?:rs|inr|₹|amount)\\.?\\s*([\\d,]+\\.?\\d*)", Pattern.CASE_INSENSITIVE)
        val amountMatcher = amountPattern.matcher(message)

        if (amountMatcher.find()) {
            // group(1) can be null, so we use a safe call
            val amountStr = amountMatcher.group(1)?.replace(",", "")
            val amount = amountStr?.toDoubleOrNull()

            if (amount != null) {
                val transactionId = System.currentTimeMillis().toString()
                val notificationId = System.currentTimeMillis().toInt()
                Log.d("SmsReceiver", "Parsed amount: $amount, type: $transactionType, id: $transactionId")
                android.util.Log.d("SmsReceiver", "Parsed amount: $amount, type: $transactionType, id: $transactionId")
                savePendingTransaction(context, transactionId, transactionType, amount, notificationId)
                showTransactionNotification(context, transactionId, transactionType, amount, notificationId)
            }
        }
    }

    private fun savePendingTransaction(context: Context, id: String, type: String, amount: Double, notificationId: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(KEY_PENDING_TRANSACTIONS, "[]")
        val transactions = try {
            val jsonArray = JSONArray(existingJson)
            val list = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                list.add(jsonArray.getJSONObject(i))
            }
            list
        } catch (e: JSONException) {
            mutableListOf()
        }

        val newTransaction = JSONObject().apply {
            put("id", id)
            put("type", type)
            put("amount", amount)
            put("timestamp", System.currentTimeMillis())
            put("notificationId", notificationId)
        }

        transactions.add(newTransaction)

        prefs.edit().putString(KEY_PENDING_TRANSACTIONS, JSONArray(transactions).toString()).apply()
        Log.d("SmsReceiver", "Saved pending transaction: $newTransaction")
        android.util.Log.d("SmsReceiver", "Saved pending transaction: $newTransaction")
    }


    private fun showTransactionNotification(context: Context, id: String, type: String, amount: Double, notificationId: Int) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "transaction_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Transactions", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        // Create an Intent to launch MainActivity
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = "ADD_TRANSACTION_FROM_SMS"
            putExtra("transaction_id", id)
            putExtra("transaction_type", type)
            putExtra("transaction_amount", amount)
            putExtra("notification_id", notificationId) // Pass the ID
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId, // Use the same unique ID for the request code
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (type == "income") "You got paid! 🥳" else "Did you pay someone? 👀"
        val content = "Amount: ₹${"%.2f".format(amount)}. Tap to add."

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(0, "Add to Wallzy", pendingIntent)
            .build()

        notificationManager.notify(notificationId, notification)
    }
}