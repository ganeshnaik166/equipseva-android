package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Pending writes captured offline. WorkManager flushes these when connectivity returns.
 * `kind` discriminates the operation; `payload` is JSON the worker decodes per-kind.
 */
@Entity(tableName = "outbox")
data class OutboxEntryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val kind: String,
    val payload: String,
    val createdAt: Long,
    val attempts: Int = 0,
    val lastError: String? = null,
)
