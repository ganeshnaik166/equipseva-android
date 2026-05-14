package com.equipseva.app.core.data.notifications

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
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

/**
 * Read-side surface for the in-app notifications inbox. Inserts are
 * server-only (no client INSERT API by design); only observe + read-state
 * mutations are exposed.
 */
@Singleton
class NotificationRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    /**
     * Emits the latest list of notifications for the user, newest first.
     * Re-emits whenever the realtime channel reports an INSERT/UPDATE/DELETE
     * on `public.notifications`.
     */
    fun observeNotifications(userId: String): Flow<List<Notification>> = callbackFlow {
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

    /**
     * One-shot fetch used by pull-to-refresh. Mirrors the same query
     * [observeNotifications] uses on subscribe.
     */
    suspend fun refreshNotifications(userId: String): Result<List<Notification>> = runCatching {
        fetchFor(userId)
    }

    /** Mark a single notification read (UPDATE read_at = now()). */
    suspend fun markRead(id: String): Result<Unit> = runCatching {
        // RLS restricts the row set to (auth.uid() = user_id); the BEFORE
        // UPDATE trigger added in 20260425001745_notifications_baseline keeps
        // the column-set guard server-side. We send a wall-clock timestamp
        // because Postgrest doesn't support `now()` literally on update().
        //
        // Defense-in-depth filter on user_id too: a future RLS regression
        // or a misconfigured policy would otherwise silently widen the
        // mutation. Mirrors markAllRead's same-author guard.
        val uid = client.auth.currentUserOrNull()?.id
            ?: error("markRead refused: no signed-in user")
        client.from(TABLE).update({
            set("read_at", Instant.now().toString())
            set("is_read", true)
        }) {
            filter {
                eq("id", id)
                eq("user_id", uid)
            }
        }
        Unit
    }

    /** Mark every unread notification owned by the user as read. */
    suspend fun markAllRead(userId: String): Result<Unit> = runCatching {
        // Defense-in-depth: refuse a caller that passes someone else's
        // user id. RLS already enforces "you can only update rows where
        // user_id = auth.uid()", but a fail-fast guard here means a logic
        // bug (e.g. caching a previous session's userId across sign-out)
        // surfaces as an exception locally instead of a no-op against
        // an empty filtered set.
        val authUid = client.auth.currentUserOrNull()?.id
        require(authUid != null && authUid == userId) {
            "markAllRead refused: signed-in user does not match target id"
        }
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
