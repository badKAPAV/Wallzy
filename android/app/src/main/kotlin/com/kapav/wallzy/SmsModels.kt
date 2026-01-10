package com.kapav.wallzy

data class SmsParsingRule(
    val ruleName: String,
    val senderRegex: Regex,
    val messageRegex: Regex,
    val staticData: Map<String, String>, // type, bankName, etc.
    val extractionStrategy: ExtractionStrategy
)

data class ExtractionStrategy(
    val amountGroup: String = "amount",
    val accountGroup: String? = null,
    val payeeGroup: String? = null,
    val balanceGroup: String? = null,
    val dateGroup: String? = null,
    val dateFormat: String? = null
)