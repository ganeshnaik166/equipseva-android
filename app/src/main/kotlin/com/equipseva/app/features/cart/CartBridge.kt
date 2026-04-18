package com.equipseva.app.features.cart

import com.equipseva.app.core.data.cart.CartItemEntity
import com.equipseva.app.core.data.parts.SparePart
import kotlin.math.roundToLong

/**
 * Adapter between the marketplace domain model and the local cart entity.
 *
 * Kept as a thin helper so that whenever `PartDetailScreen` (or any other
 * surface) wants to add-to-cart, it can do:
 *
 *     cartRepository.addOrIncrement(CartBridge.buildCartItem(part))
 *
 * without knowing how rupees → paise conversion or primary-image selection
 * works under the hood.
 */
object CartBridge {

    /**
     * Convert a SparePart (rupees as Double) into a CartItemEntity (paise as
     * Long). Rounds to the nearest paise to avoid 0.01-rupee drift from upstream.
     */
    fun buildCartItem(
        part: SparePart,
        addedAtEpochMs: Long = System.currentTimeMillis(),
    ): CartItemEntity = CartItemEntity(
        partId = part.id,
        name = part.name,
        unitPriceInPaise = (part.priceRupees * 100.0).roundToLong(),
        quantity = 1,
        imageUrl = part.primaryImageUrl,
        addedAtEpochMs = addedAtEpochMs,
    )
}
