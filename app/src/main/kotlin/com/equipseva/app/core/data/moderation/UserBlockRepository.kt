package com.equipseva.app.core.data.moderation

import kotlinx.coroutines.flow.Flow

interface UserBlockRepository {
    fun observeBlockedUserIds(): Flow<Set<String>>
    suspend fun block(blockedUserId: String): Result<Unit>
    suspend fun unblock(blockedUserId: String): Result<Unit>
    suspend fun isBlocked(blockedUserId: String): Result<Boolean>
}
