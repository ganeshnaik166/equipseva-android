package com.equipseva.app.core.data.cart

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Local-first cart line. Phase 1 source of truth lives on-device in Room.
 *
 * `unitPriceInPaise` is stored as Long paise to avoid floating-point drift on
 * totals. `addedAtEpochMs` is indexed because the cart screen renders most-
 * recently-added first.
 */
@Entity(
    tableName = "cart_line_items",
    indices = [Index(value = ["addedAtEpochMs"], orders = [Index.Order.DESC])],
)
data class CartItemEntity(
    @PrimaryKey val partId: String,
    val name: String,
    val unitPriceInPaise: Long,
    val quantity: Int,
    val imageUrl: String?,
    val addedAtEpochMs: Long,
)
