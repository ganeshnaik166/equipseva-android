package com.equipseva.app.core.data.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import com.equipseva.app.core.data.entities.MessageEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MessageDao {
    @Query("SELECT * FROM messages WHERE threadId = :threadId ORDER BY createdAt ASC")
    fun observeThread(threadId: String): Flow<List<MessageEntity>>

    @Upsert
    suspend fun upsert(message: MessageEntity)

    @Upsert
    suspend fun upsertAll(messages: List<MessageEntity>)

    @Query("UPDATE messages SET readAt = :readAt WHERE threadId = :threadId AND readAt IS NULL")
    suspend fun markThreadRead(threadId: String, readAt: Long)
}
