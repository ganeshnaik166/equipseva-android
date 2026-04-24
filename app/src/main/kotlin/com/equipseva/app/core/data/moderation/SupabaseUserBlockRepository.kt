package com.equipseva.app.core.data.moderation

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseUserBlockRepository @Inject constructor(
    private val client: SupabaseClient,
) : UserBlockRepository {

    @Serializable
    private data class BlockedRow(val blocked_user_id: String)

    private val cache = MutableStateFlow<Set<String>?>(null)
    private val mutex = Mutex()

    override fun observeBlockedUserIds(): Flow<Set<String>> {
        // Lazy-refresh on first subscriber to avoid hitting Supabase pre-auth.
        return object : Flow<Set<String>> {
            override suspend fun collect(collector: kotlinx.coroutines.flow.FlowCollector<Set<String>>) {
                if (cache.value == null) {
                    runCatching { refresh() }
                }
                cache.asStateFlow().collect { value ->
                    collector.emit(value ?: emptySet())
                }
            }
        }.flowOn(Dispatchers.IO)
    }

    override suspend fun block(blockedUserId: String): Result<Unit> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) { "Not signed in" }
        require(userId != blockedUserId) { "Cannot block self" }
        client.from(TABLE).insert(
            buildJsonObject {
                put("blocker_user_id", JsonPrimitive(userId))
                put("blocked_user_id", JsonPrimitive(blockedUserId))
            },
        )
        mutex.withLock { cache.value = (cache.value ?: emptySet()) + blockedUserId }
    }

    override suspend fun unblock(blockedUserId: String): Result<Unit> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) { "Not signed in" }
        client.from(TABLE).delete {
            filter {
                eq("blocker_user_id", userId)
                eq("blocked_user_id", blockedUserId)
            }
        }
        mutex.withLock { cache.value = (cache.value ?: emptySet()) - blockedUserId }
    }

    override suspend fun isBlocked(blockedUserId: String): Result<Boolean> = runCatching {
        val current = cache.value
        if (current != null) return@runCatching blockedUserId in current
        refresh()
        blockedUserId in (cache.value ?: emptySet())
    }

    private suspend fun refresh() = withContext(Dispatchers.IO) {
        val userId = client.auth.currentUserOrNull()?.id ?: run {
            cache.value = emptySet()
            return@withContext
        }
        val rows = client.from(TABLE).select(columns = Columns.list("blocked_user_id")) {
            filter { eq("blocker_user_id", userId) }
            limit(count = 5000)
        }.decodeList<BlockedRow>()
        cache.value = rows.map { it.blocked_user_id }.toSet()
    }

    private companion object {
        const val TABLE = "user_blocks"
    }
}
