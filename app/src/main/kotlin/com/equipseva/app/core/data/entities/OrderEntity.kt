package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "orders")
data class OrderEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val status: String,
    val totalMinor: Long,
    val currency: String,
    val razorpayOrderId: String?,
    val placedAt: Long,
    val updatedAt: Long,
)
