package com.kapav.wallzy

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class BankNotificationListenerService : NotificationListenerService() {

    // Covers Pixel, Samsung, Xiaomi, Oppo, Vivo, Realme, OnePlus, Motorola
    private val smsPackages = setOf(
        "com.google.android.apps.messaging",
        "com.android.messaging",
        "com.samsung.android.messaging",
        "com.miui.sms",
        "com.coloros.mms",
        "com.coloros.sms",
        "com.oppo.messaging",
        "com.vivo.messaging",
        "com.asus.messaging",
        "com.motorola.messaging",
        "com.nothing.messaging" // Added Nothing Phone support
    )

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            // 1. Package Filter (Keep existing)
            val packageName = sbn.packageName
            if (packageName !in smsPackages) return

            val extras = sbn.notification.extras

            // 2. Extract Message Body
            val messageBody = extras.getCharSequence("android.bigText")?.toString()
                ?: extras.getCharSequence("android.text")?.toString()
                ?: return

            // 3. Extract Sender Name (Crucial for V3 Parser)
            // The notification title usually holds the Sender ID (e.g. "HDFC Bank", "VM-SBIUPS")
            val senderTitle = extras.getCharSequence("android.title")?.toString() ?: ""

            // 4. Safety Filters
            // Ignore OTPs immediately to save processing (Optimization)
            if (messageBody.contains("OTP", ignoreCase = true) || 
                messageBody.length < 20) {
                return
            }

            Log.d("BankListener", "SMS Intercepted from: $senderTitle")

            // 5. Pass BOTH Sender and Body to the Parser
            // This allows the Parser to use 'senderRegex' from your JSON to filter rules efficiently.
            SmsTransactionParser.parseMessageAndNotify(
                applicationContext, 
                messageBody, 
                senderTitle
            )

        } catch (e: Exception) {
            Log.e("BankListener", "Error processing notification", e)
        }
    }
}