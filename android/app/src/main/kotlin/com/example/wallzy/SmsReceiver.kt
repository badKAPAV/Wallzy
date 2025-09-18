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
import java.util.UUID
import java.util.regex.Pattern
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME = "SmsPendingTransactions"
        const val KEY_PENDING_TRANSACTIONS = "pending_transactions"

        // Regex patterns for parsing
        private val bankPattern = Pattern.compile("\\b(SBI|HDFC|ICICI|AXIS|KOTAK|PNB|BOB|CANARA|UNION|IDBI|INDIAN|UCO|CENTRAL|IOB|CITI|HSBC|YES|INDUSIND)\\b", Pattern.CASE_INSENSITIVE)
        private val accountPattern = Pattern.compile("(?:a/c|acct|account)\\s(?:no[ .]*)?(?:ending\\s)?(?:with\\s)?(x*\\d{4,6})", Pattern.CASE_INSENSITIVE)
        private val vpaPattern = Pattern.compile("(?:to|from|\\bat\\b)\\s+([a-zA-Z0-9.\\-_]+@[a-zA-Z]+)", Pattern.CASE_INSENSITIVE)
        private val namePattern = Pattern.compile("(?:to|from|\\bat\\b)\\s+([A-Z][A-Za-z\\s.]{3,30})(?:\\s+on|\\s+with|\\s+Ref|\\s+for|\\s*\\.)", Pattern.CASE_INSENSITIVE)
        private val amountPattern = Pattern.compile("\\b(?:rs|inr|₹|amount|debited by|credited by|paid|received)\\b\\.?\\s*([\\d,]+(?:\\.\\d+)?)", Pattern.CASE_INSENSITIVE)

        // Keyword maps for category parsing.
        // In a real-world scenario, you mentioned wanting this to be dynamic from Firebase.
        // Fetching from Firebase inside a BroadcastReceiver is not recommended due to its short lifecycle.
        // A better approach is to pass the whole SMS body to the Flutter app and let Flutter perform
        // the dynamic category matching after fetching the rules from Firebase.
        // For this demonstration, I'm using a hardcoded map as requested.
        private val foodKeywords = listOf("zomato", "swiggy", "ubereats", "domino", "pizza hut", "restaurant", "cafe")
        private val shoppingKeywords = listOf("amazon", "flipkart", "myntra", "ajio", "bigbasket", "grofers", "mart")
        private val entertainmentKeywords = listOf("bookmyshow", "pvr", "inox", "netflix", "spotify", "prime video")
        private val salaryKeywords = listOf("salary", "payroll")
    }
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            messages.forEach { smsMessage ->
                val msgBody = smsMessage.messageBody
                Log.d("SmsReceiver", "Message Received: $msgBody")
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
        val paymentMethod = getPaymentMethod(lowerCaseMessage)
        val bankName = getBankName(message)
        val accountNumber = getAccountNumber(message)
        val payee = getPayee(message)
        var category = getCategory(lowerCaseMessage)

        // If category is salary, it must be an income transaction
        if (category == "Salary" && transactionType == "expense") {
            category = null // It's not a salary expense
        }

        val amountMatcher = amountPattern.matcher(message)

        if (amountMatcher.find()) {
            // group(1) can be null, so we use a safe call
            val amountStr = amountMatcher.group(1)?.replace(",", "")
            val amount = amountStr?.toDoubleOrNull()
            
            if (amount != null) {
                val transactionId = UUID.randomUUID().toString()
                val notificationId = System.currentTimeMillis().toInt()
                Log.d("SmsReceiver", "Parsed: amount=$amount, type=$transactionType, method=$paymentMethod, bank=$bankName, acct=$accountNumber, payee=$payee, category=$category")
                savePendingTransaction(context, transactionId, transactionType, amount, notificationId, paymentMethod, bankName, accountNumber, payee, category)
                showTransactionNotification(context, transactionId, transactionType, amount, notificationId, paymentMethod, bankName, accountNumber, payee, category)
                // NEW: Notify running activity that new data is available
                notifyActivityOfNewSms(context)
            }
        }
    }

    // NEW: Method to send broadcast to a running activity
    private fun notifyActivityOfNewSms(context: Context) {
        val intent = Intent("com.example.wallzy.NEW_PENDING_SMS_ACTION")
        // By setting the package, we ensure only our app's components can receive it.
        // This is a security measure.
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
        Log.d("SmsReceiver", "Sent broadcast to notify activity of new pending SMS.")
    }

    private fun getPaymentMethod(lowerCaseMessage: String): String {
        return when {
            lowerCaseMessage.contains("upi") -> "UPI"
            lowerCaseMessage.contains("neft") ||
            lowerCaseMessage.contains("rtgs") ||
            lowerCaseMessage.contains("imps") ||
            lowerCaseMessage.contains("bank transfer") -> "Net banking"
            lowerCaseMessage.contains("card") -> "Card"
            else -> "Other"
        }
    }

    private fun getBankName(message: String): String? {
        val matcher = bankPattern.matcher(message)
        return if (matcher.find()) matcher.group(1)?.uppercase(Locale.getDefault()) else null
    }

    private fun getAccountNumber(message: String): String? {
        val matcher = accountPattern.matcher(message)
        return if (matcher.find()) matcher.group(1) else null
    }

    private fun getPayee(message: String): String? {
        // Prioritize VPA (UPI ID) as it's more specific
        var matcher = vpaPattern.matcher(message)
        if (matcher.find()) {
            return matcher.group(1)
        }
        // Then look for a capitalized name
        matcher = namePattern.matcher(message)
        if (matcher.find()) {
            return matcher.group(1)?.trim()
        }
        return null
    }

    private fun getCategory(lowerCaseMessage: String): String? {
        return when {
            salaryKeywords.any { lowerCaseMessage.contains(it) } -> "Salary"
            foodKeywords.any { lowerCaseMessage.contains(it) } -> "Food"
            shoppingKeywords.any { lowerCaseMessage.contains(it) } -> "Shopping"
            entertainmentKeywords.any { lowerCaseMessage.contains(it) } -> "Entertainment"
            else -> null
        }
    }
    private fun savePendingTransaction(context: Context, id: String, type: String, amount: Double, notificationId: Int, paymentMethod: String, bankName: String?, accountNumber: String?, payee: String?, category: String?) {
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
            put("paymentMethod", paymentMethod)
            put("bankName", bankName)
            put("accountNumber", accountNumber)
            put("payee", payee)
            put("category", category)
        }

        transactions.add(newTransaction)

        prefs.edit().putString(KEY_PENDING_TRANSACTIONS, JSONArray(transactions).toString()).apply()
        Log.d("SmsReceiver", "Saved pending transaction: $newTransaction")
    }

    private fun showTransactionNotification(context:Context, id: String, type: String, amount: Double, notificationId: Int, paymentMethod: String, bankName: String?, accountNumber: String?, payee: String?, category: String?) {
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
            putExtra("payment_method", paymentMethod) // NEW
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId, // Use the same unique ID for the request code
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (type == "income") "You got paid! 🥳" else "Did you pay someone? 👀"
        val formattedAmount = "₹${"%.2f".format(amount)}"

        val content = when {
            payee != null && type == "expense" -> "Paid $formattedAmount to $payee. Tap to add."
            payee != null && type == "income" -> "Received $formattedAmount from $payee. Tap to add."
            else -> "Transaction of $formattedAmount via $paymentMethod. Tap to add."
        }

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