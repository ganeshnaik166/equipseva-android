package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "device_token")
data class DeviceTokenEntity(
    @PrimaryKey val id: Int = 0,
    val token: String,
    val platform: String = "android",
    val registeredAt: Long,
)
