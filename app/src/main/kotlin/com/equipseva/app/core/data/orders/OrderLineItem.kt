package com.equipseva.app.core.data.orders

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Line-item shape serialised into the `spare_part_orders.items` jsonb column. Kept flat so
 * future columns on `spare_parts` don't force an order-row migration; the checkout VM
 * snapshots part price/tax at purchase time.
 */
@Serializable
data class OrderLineItem(
    @SerialName("part_id") val partId: String,
    val name: String,
    @SerialName("part_number") val partNumber: String? = null,
    val quantity: Int,
    @SerialName("unit_price") val unitPriceRupees: Double,
    @SerialName("gst_rate") val gstRatePercent: Double = 0.0,
    @SerialName("image_url") val imageUrl: String? = null,
) {
    val lineSubtotalRupees: Double get() = unitPriceRupees * quantity
    val lineGstRupees: Double get() = lineSubtotalRupees * (gstRatePercent / 100.0)
    val lineTotalRupees: Double get() = lineSubtotalRupees + lineGstRupees
}
