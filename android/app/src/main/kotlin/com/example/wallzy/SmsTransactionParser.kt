package com.example.wallzy

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Locale
import java.util.UUID
import java.util.regex.Pattern

object SmsTransactionParser {

    // ⬇️⬇️⬇️ COPIED FROM SmsReceiver COMPANION OBJECT ⬇️⬇️⬇️
    
    private const val PREFS_NAME = "SmsPendingTransactions"
    private const val KEY_PENDING_TRANSACTIONS = "pending_transactions"

    // --- 1. CORE MATCHING PATTERNS ---
    private val debitKeywords = Pattern.compile("\\b(debited|spent|paid|sent|withdrawn|purchase|transfer|transferred)\\b", Pattern.CASE_INSENSITIVE)
    private val creditKeywords = Pattern.compile("\\b(credited|received|deposit|refund|added|salary|reversal)\\b", Pattern.CASE_INSENSITIVE)
    
    // FIX 1: Updated Spam Keywords to catch "SmartEMI", "Vouchers", "Split", "Convert"
    private val spamKeywords = Pattern.compile("\\b(plan|data|gb|pack|validity|prepaid|postpaid|rollover|upgrade|expires|rewards|otp|verification|code|emi|voucher|gift|convert|split|eligible|limit|win)\\b", Pattern.CASE_INSENSITIVE)
    
    private val accountIndicator = Pattern.compile("\\b(a/c|acct|card|bank|wallet|upi|account|vpa|xx)\\b", Pattern.CASE_INSENSITIVE)

    // Extraction Patterns
    private val bankPattern = Pattern.compile("\\b(SBI|HDFC|ICICI|AXIS|KOTAK|PNB|BOB|CANARA|UNION|IDBI|INDIAN|UCO|CENTRAL|IOB|CITI|HSBC|YES|INDUSIND|PAYTM|GPAY|PHONEPE|CRED)\\b", Pattern.CASE_INSENSITIVE)
    private val accountPattern = Pattern.compile("(?:a/c|acct|account)\\s*(?:no\\.?\\s*)?(?:ending\\s+)?(?:with\\s+)?\\s*[x*]+\\s*(\\d{4})", Pattern.CASE_INSENSITIVE)
    private val vpaPattern = Pattern.compile("(?:to|from|\\bat\\b)\\s+([a-zA-Z0-9.\\-_]+@[a-zA-Z]+)", Pattern.CASE_INSENSITIVE)
    private val namePattern = Pattern.compile("(?:to|from|\\bat\\b)\\s+([A-Z][A-Za-z\\s.]{3,30})(?:\\s+on|\\s+with|\\s+Ref|\\s+for|\\s*\\.)", Pattern.CASE_INSENSITIVE)
    
    // FIX 2: More robust amount regex
    private val amountPattern = Pattern.compile("(?i)(?:(?:RS|INR|MRP)\\.?\\s?)(\\d+(?:,\\d+)*(?:\\.\\d{1,2})?)")

    // --- 2. CATEGORY KEYWORD MAPPING ---
    private val groceryKeywords = listOf("bigbasket", "blinkit", "zepto", "instamart", "grofers", "dmart", "reliance fresh", "nature's basket", "kirana", "supermarket", "vegetable", "fruit", "grocery")
    private val foodKeywords = listOf("zomato", "swiggy", "ubereats", "domino", "pizza", "burger", "kfc", "mcdonald", "cafe", "coffee", "starbucks", "tea", "dining", "kitchen", "restaurant", "baking", "bakery", "cake", "eats", "bar", "pub")
    private val transportKeywords = listOf("uber", "ola", "rapido", "indrive", "metro", "rail", "irctc", "fastag", "toll", "ticket", "cab", "auto")
    private val fuelKeywords = listOf("petrol", "diesel", "shell", "hpcl", "bpcl", "ioc", "pump", "fuel", "gas station")
    private val shoppingKeywords = listOf("amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa", "tata", "reliance trends", "zudio", "pantaloons", "mall", "retail", "store", "mart", "cloth", "fashion", "decathlon", "nike", "adidas")
    private val entertainmentKeywords = listOf("bookmyshow", "pvr", "inox", "netflix", "prime", "hotstar", "spotify", "youtube", "game", "steam", "playstation", "movie", "cinema", "subscription")
    private val healthKeywords = listOf("pharmacy", "medplus", "apollo", "1mg", "practo", "hospital", "doctor", "clinic", "lab", "meds", "health", "dr.")
    private val utilityKeywords = listOf("electricity", "bescom", "tneb", "discom", "gas", "water", "broadband", "internet", "wifi", "fiber", "dth", "cable")
    private val investmentKeywords = listOf("zerodha", "groww", "kite", "sip", "mutual fund", "stock", "angel one", "upstox", "coin", "nps", "ppf", "smallcase")
    private val educationKeywords = listOf("school", "college", "fee", "university", "udemy", "coursera", "learning", "class")
    private val billKeywords = listOf("bill", "recharge", "invoice", "premium")
    private val rentKeywords = listOf("rent", "nobroker", "nestaway")
    private val loanKeywords = listOf("loan", "emi", "finance", "bajaj")
    private val refundKeywords = listOf("refund", "reversal", "reversed")
    private val salaryKeywords = listOf("salary", "payroll", "credit towards salary")

    // ⬆️⬆️⬆️ END COPY ⬆️⬆️⬆️

    fun parseMessageAndNotify(context: Context, message: String) {
        // ⬇️⬇️⬇️ COPY YOUR parseMessageAndNotify METHOD BODY EXACTLY ⬇️⬇️⬇️
        
        val cleanMsg = message.lowercase(Locale.getDefault())

        // 1. SPAM BLOCKER
        if (spamKeywords.matcher(message).find()) {
            Log.d("SmsTransactionParser", "Ignored SPAM: $message")
            return
        }

        // 2. TRANSACTION CHECK
        val hasAccountContext = accountIndicator.matcher(message).find()
        val isCredit = creditKeywords.matcher(message).find()
        val isDebit = debitKeywords.matcher(message).find()

        // FIX 3: STRICT CHECK
        // We require a debit/credit keyword to exist. 
        // Previously, having just "HDFC Bank" (context) was enough to pass this check.
        if (!isCredit && !isDebit) {
            return
        }

        // If it has keywords but NO context (e.g. "Paid 500"), ignore it unless it's UPI.
        if (!hasAccountContext && !message.contains("UPI", ignoreCase = true)) {
            return
        }

        // 3. EXTRACTION
        val transactionType = if (isCredit) "income" else "expense"
        val paymentMethod = getPaymentMethod(cleanMsg)
        val bankName = getBankName(message)
        val accountNumber = getAccountNumber(message)
        val payee = getPayee(message)
        
        var category = getCategory(cleanMsg, transactionType)

        val amountMatcher = amountPattern.matcher(message)

        if (amountMatcher.find()) {
            val amountStr = amountMatcher.group(1)?.replace(",", "")
            val amount = amountStr?.toDoubleOrNull()
            
            if (amount != null) {
                val transactionId = UUID.randomUUID().toString()
                val notificationId = System.currentTimeMillis().toInt()
                
                if (transactionType == "income" && category == null) {
                    category = "Others" 
                }
                
                savePendingTransaction(context, transactionId, transactionType, amount, notificationId, paymentMethod, bankName, accountNumber, payee, category)
                showTransactionNotification(context, transactionId, transactionType, amount, notificationId, paymentMethod, bankName, accountNumber, payee, category)
                notifyActivityOfNewSms(context)
            }
        }
        
        // ⬆️⬆️⬆️ END COPY ⬆️⬆️⬆️
    }

    // ⬇️ COPY ALL HELPER METHODS UNCHANGED ⬇️

    private fun getCategory(msg: String, type: String): String? {
        if (refundKeywords.any { msg.contains(it) } && type == "income") return "Refund"
        if (salaryKeywords.any { msg.contains(it) } && type == "income") return "Salary"
        if (loanKeywords.any { msg.contains(it) }) return "Loan"

        return when {
            groceryKeywords.any { msg.contains(it) } -> "Grocery"
            foodKeywords.any { msg.contains(it) } -> "Food"
            fuelKeywords.any { msg.contains(it) } -> "Fuel"
            transportKeywords.any { msg.contains(it) } -> "Transport"
            entertainmentKeywords.any { msg.contains(it) } -> "Entertainment"
            healthKeywords.any { msg.contains(it) } -> "Health"
            shoppingKeywords.any { msg.contains(it) } -> "Shopping"
            investmentKeywords.any { msg.contains(it) } -> "Investment"
            educationKeywords.any { msg.contains(it) } -> "Education"
            rentKeywords.any { msg.contains(it) } -> "Rent"
            utilityKeywords.any { msg.contains(it) } -> "Utilities"
            billKeywords.any { msg.contains(it) } -> "Bills"
            else -> null 
        }
    }

    private fun getPaymentMethod(lowerCaseMessage: String): String {
        return when {
            lowerCaseMessage.contains("upi") -> "UPI"
            lowerCaseMessage.contains("neft") || lowerCaseMessage.contains("rtgs") || lowerCaseMessage.contains("imps") -> "Net banking"
            lowerCaseMessage.contains("card") || lowerCaseMessage.contains("debit") || lowerCaseMessage.contains("credit") -> "Card"
            else -> "Other"
        }
    }

    private fun notifyActivityOfNewSms(context: Context) {
        val intent = Intent("com.example.wallzy.NEW_PENDING_SMS_ACTION")
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
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
        var matcher = vpaPattern.matcher(message)
        if (matcher.find()) return matcher.group(1)
        matcher = namePattern.matcher(message)
        if (matcher.find()) return matcher.group(1)?.trim()
        return null
    }

    private fun savePendingTransaction(context: Context, id: String, type: String, amount: Double, notificationId: Int, paymentMethod: String, bankName: String?, accountNumber: String?, payee: String?, category: String?) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(KEY_PENDING_TRANSACTIONS, "[]")
        val transactions = try {
            val jsonArray = JSONArray(existingJson)
            val list = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) { list.add(jsonArray.getJSONObject(i)) }
            list
        } catch (e: JSONException) { mutableListOf() }

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
    }

    private fun showTransactionNotification(context: Context, id: String, type: String, amount: Double, notificationId: Int, paymentMethod: String, bankName: String?, accountNumber: String?, payee: String?, category: String?) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "transaction_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Transactions", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val transactionJson = JSONObject().apply {
            put("id", id)
            put("type", type)
            put("amount", amount)
            put("paymentMethod", paymentMethod)
            put("bankName", bankName)
            put("accountNumber", accountNumber)
            put("payee", payee)
            put("category", category)
        }.toString()

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = "ADD_TRANSACTION_FROM_SMS"
            putExtra("notification_id", notificationId)
            putExtra("wallzy.transaction.json", transactionJson)
        }

        val pendingIntent = PendingIntent.getActivity(context, notificationId, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val formattedAmount = "₹${"%.2f".format(amount)}"
        val title = when {
            payee != null && type == "expense" -> "Sent $formattedAmount to $payee"
            payee != null && type == "income" -> "Received $formattedAmount from $payee"
            type == "expense" -> "Sent $formattedAmount via $paymentMethod"
            else -> "Received $formattedAmount"
        }

        val content = buildString {
            val direction = if (type == "expense") "From" else "To"
            if (!bankName.isNullOrBlank() && !accountNumber.isNullOrBlank()) {
                append("$direction $bankName XX$accountNumber")
                if (!paymentMethod.isNullOrBlank()) append(" via $paymentMethod")
                append(". ")
            }
            append("Tap to add.")
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