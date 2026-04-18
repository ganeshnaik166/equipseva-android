package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "repair_jobs")
data class RepairJobEntity(
    @PrimaryKey val id: String,
    val hospitalId: String,
    val engineerId: String?,
    val equipmentName: String,
    val status: String,
    val description: String,
    val scheduledFor: Long?,
    val createdAt: Long,
    val updatedAt: Long,
)
