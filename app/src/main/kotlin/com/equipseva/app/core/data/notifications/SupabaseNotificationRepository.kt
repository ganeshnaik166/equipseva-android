package com.equipseva.app.core.data.notifications

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseNotificationRepository @Inject constructor(
    private val client: SupabaseClient,
) : NotificationRepository {

    override fun observeNotifications(userId: String): Flow<List<Notification>> = callbackFlow {
        suspend fun refresh() {
            runCatching { fetchFor(userId) }.onSuccess { trySend(it) }
        }
        // Prime with the current snapshot so the screen doesn't have to wait
        // for the first realtime event before showing data.
        refresh()

        val channel = client.channel("notifications:$userId")
        // Filter on user_id at the realtime layer too — RLS already restricts
        // visibility, but filtering keeps the wire traffic bounded.
        val changes = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = TABLE
            // Filter at the realtime layer too — RLS already restricts visibility,
            // but filtering keeps wire traffic bounded to this user's rows.
            filter("user_id", FilterOperator.EQ, userId)
        }
        val job = launch {
            changes.collect { _ -> refresh() }
        }
        channel.subscribe()

        awaitClose {
            job.cancel()
            launch { client.realtime.removeChannel(channel) }
        }
    }.flowOn(Dispatchers.IO)

    override suspend fun refreshNotifications(userId: String): Result<List<Notification>> = runCatching {
        fetchFor(userId)
    }

    override suspend fun markRead(id: String): Result<Unit> = runCatching {
        // RLS restricts the row set to (auth.uid() = user_id); the BEFORE
        // UPDATE trigger added in 20260425001745_notifications_baseline keeps
        // the column-set guard server-side. We send a wall-clock timestamp
        // because Postgrest doesn't support `now()` literally on update().
        client.from(TABLE).update({
            set("read_at", Instant.now().toString())
            set("is_read", true)
        }) {
            filter { eq("id", id) }
        }
        Unit
    }

    override suspend fun markAllRead(userId: String): Result<Unit> = runCatching {
        val nowIso = Instant.now().toString()
        client.from(TABLE).update({
            set("read_at", nowIso)
            set("is_read", true)
        }) {
            filter {
                eq("user_id", userId)
                // `is.null` — only flip rows that haven't been read yet.
                filter("read_at", FilterOperator.IS, "null")
            }
        }
        Unit
    }

    private suspend fun fetchFor(userId: String): List<Notification> =
        client.from(TABLE).select {
            filter { eq("user_id", userId) }
            order("sent_at", order = Order.DESCENDING, nullsFirst = false)
            limit(count = 200)
        }.decodeList<NotificationDto>().map(NotificationDto::toDomain)

    private companion object {
        const val TABLE = "notifications"
    }
}
