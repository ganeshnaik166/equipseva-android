package com.equipseva.app.core.data.cart

/**
 * UI-facing cart line. Keeps paise as Long so totals stay exact; the UI layer
 * converts to rupees (Double) only at the point of display.
 */
data class CartItem(
    val partId: String,
    val name: String,
    val unitPriceInPaise: Long,
    val quantity: Int,
    val imageUrl: String?,
    val addedAtEpochMs: Long,
) {
    val lineTotalInPaise: Long get() = unitPriceInPaise * quantity
}

internal fun CartItemEntity.toDomain(): CartItem = CartItem(
    partId = partId,
    name = name,
    unitPriceInPaise = unitPriceInPaise,
    quantity = quantity,
    imageUrl = imageUrl,
    addedAtEpochMs = addedAtEpochMs,
)
