package com.medeq.app.domain

/**
 * Domain model used by the UI layer.
 * Decoupled from Room/Retrofit so we can map either source into it.
 */
data class Equipment(
    val id: Long,
    val source: Source,
    val udi: String?,
    val itemName: String,
    val brand: String?,
    val model: String?,
    val category: String,
    val subCategory: String?,
    val type: String?,
    val specifications: String?,
    val priceInrLow: Long?,
    val priceInrHigh: Long?,
    val market: String?,
    val imageSearchUrl: String?,
    val notes: String?,
) {
    enum class Source { CURATED, GUDID, REMOTE }

    val priceRangeLabel: String?
        get() {
            val low = priceInrLow ?: return null
            val high = priceInrHigh ?: return formatInr(low)
            return if (low == high) formatInr(low) else "${formatInr(low)} – ${formatInr(high)}"
        }

    companion object {
        fun formatInr(amount: Long): String {
            // Indian numbering: 1,00,000 / 1,00,00,000
            if (amount < 1000) return "₹$amount"
            val s = amount.toString()
            val last3 = s.takeLast(3)
            val rest = s.dropLast(3)
            val grouped = rest.reversed().chunked(2).joinToString(",").reversed()
            return "₹$grouped,$last3"
        }
    }
}
