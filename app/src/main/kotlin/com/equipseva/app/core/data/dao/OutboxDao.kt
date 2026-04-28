package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface OutboxDao {
    @Insert
    suspend fun enqueue(entry: OutboxEntryEntity): Long

    @Query("SELECT * FROM outbox ORDER BY createdAt ASC LIMIT :limit")
    suspend fun nextBatch(limit: Int = 25): List<OutboxEntryEntity>

    @Query("DELETE FROM outbox WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("UPDATE outbox SET attempts = attempts + 1, lastError = :error WHERE id = :id")
    suspend fun markFailed(id: Long, error: String)

    @Query("SELECT COUNT(*) FROM outbox")
    suspend fun pendingCount(): Int

    @Query("SELECT COUNT(*) FROM outbox WHERE kind = :kind")
    fun observePendingCountByKind(kind: String): Flow<Int>

    @Query("DELETE FROM outbox")
    suspend fun clearAll()
}
