package com.equipseva.app.core.data.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "messages",
    indices = [Index("threadId"), Index("createdAt")],
)
data class MessageEntity(
    @PrimaryKey val id: String,
    val threadId: String,
    val senderId: String,
    val body: String,
    val attachmentUrl: String?,
    val createdAt: Long,
    val deliveredAt: Long?,
    val readAt: Long?,
)
