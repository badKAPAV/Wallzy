package com.kapav.wallzy

import android.content.Context
import org.json.JSONObject
import java.io.File
import android.util.Log

object PatternRepository {
    private const val FILENAME = "sms_patterns.json"
    private var cachedRules: List<SmsParsingRule>? = null

    // In PatternRepository.kt

fun getRules(context: Context): List<SmsParsingRule> {
    if (cachedRules != null) return cachedRules!!

    val file = File(context.filesDir, FILENAME)
    val jsonString: String

    if (file.exists()) {
        Log.w("PatternRepository", "⚠️ Loading rules from INTERNAL STORAGE (Overrides Assets)")
        jsonString = file.readText()
    } else {
        Log.i("PatternRepository", "✅ Loading rules from ASSETS (Default)")
        try {
            jsonString = context.assets.open(FILENAME).bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            Log.e("PatternRepository", "Failed to load assets", e)
            return emptyList()
        }
    }
    
    // 🔥 DEBUG LOG: Print the regex to see if it matches your JSON
    // Log.d("PatternRepository", "Loaded JSON Content: $jsonString")

    cachedRules = parseJson(jsonString)
    return cachedRules!!
}

    // Called by MainActivity when Flutter sends a new update
    fun saveNewRules(context: Context, jsonContent: String) {
        try {
            val file = File(context.filesDir, FILENAME)
            file.writeText(jsonContent)
            cachedRules = null // Clear cache to force reload next time
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun parseJson(json: String): List<SmsParsingRule> {
        val list = mutableListOf<SmsParsingRule>()
        try {
            val root = JSONObject(json)
            val rulesArray = root.getJSONArray("rules")

            for (i in 0 until rulesArray.length()) {
                val obj = rulesArray.getJSONObject(i)
                if (!obj.optBoolean("active", true)) continue // Skip inactive rules

                val extractObj = obj.getJSONObject("extractionStrategy")
                
                // Convert JSON "data" object to a Map
                val staticDataMap = mutableMapOf<String, String>()
                val dataObj = obj.getJSONObject("data")
                dataObj.keys().forEach { key -> staticDataMap[key] = dataObj.getString(key) }

                list.add(SmsParsingRule(
                    ruleName = obj.optString("ruleName"),
                    senderRegex = Regex(obj.getString("senderPattern")),
                    messageRegex = Regex(obj.getString("messagePattern")),
                    staticData = staticDataMap,
                    extractionStrategy = ExtractionStrategy(
                        amountGroup = extractObj.optString("amountGroup", "amount"),
                        accountGroup = extractObj.getNullableString("accountGroup"),
                        payeeGroup = extractObj.getNullableString("payeeGroup"),
                        balanceGroup = extractObj.getNullableString("balanceGroup"),
                        dateGroup = extractObj.getNullableString("dateGroup"),
                        dateFormat = extractObj.getNullableString("dateFormat")
                    )
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }
}

// Helper extension to handle JSON nulls correctly
private fun JSONObject.getNullableString(key: String): String? {
    if (this.isNull(key)) return null
    val value = this.optString(key)
    return if (value.isEmpty() || value == "null") null else value
}