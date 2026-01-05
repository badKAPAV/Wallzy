package com.example.wallzy

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class BankNotificationListenerService : NotificationListenerService() {

    // Covers Pixel, Samsung, Xiaomi, Oppo, Vivo, Realme, OnePlus, Motorola
    private val smsPackages = setOf(
        // Google / AOSP
        "com.google.android.apps.messaging",
        "com.android.messaging",

        // Samsung
        "com.samsung.android.messaging",

        // Xiaomi / Redmi / Poco
        "com.miui.sms",

        // Oppo / Realme / OnePlus
        "com.coloros.mms",
        "com.coloros.sms",
        "com.oppo.messaging",

        // Vivo / iQOO
        "com.vivo.messaging",

        // Asus / Motorola
        "com.asus.messaging",
        "com.motorola.messaging"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val packageName = sbn.packageName
            if (packageName !in smsPackages) return

            val extras = sbn.notification.extras

            val text =
                extras.getCharSequence("android.bigText")?.toString()
                    ?: extras.getCharSequence("android.text")?.toString()
                    ?: return

            // Safety filter: ignore very short / useless notifications
            if (text.length < 20) return

            Log.d("BankListener", "SMS Notification intercepted: $text")

            // 🔥 REUSE YOUR EXACT PARSER 🔥
            SmsTransactionParser.parseMessageAndNotify(applicationContext, text)

        } catch (e: Exception) {
            Log.e("BankListener", "Error processing notification", e)
        }
    }
}
