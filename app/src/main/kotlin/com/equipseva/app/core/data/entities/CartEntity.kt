package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "cart_items")
data class CartEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val productId: String,
    val name: String,
    val unitPriceMinor: Long,
    val quantity: Int,
    val imageUrl: String?,
    val updatedAt: Long,
)
