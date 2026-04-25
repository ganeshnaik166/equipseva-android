package com.equipseva.app.core.data.notifications

import kotlinx.coroutines.flow.Flow

/**
 * Read-side surface for the in-app notifications inbox. Inserts are
 * server-only (no client INSERT API by design); this interface only
 * exposes observe + read-state mutations.
 */
interface NotificationRepository {
    /**
     * Emits the latest list of notifications for the user, newest first.
     * Re-emits whenever the realtime channel reports an INSERT/UPDATE/DELETE
     * on `public.notifications`.
     */
    fun observeNotifications(userId: String): Flow<List<Notification>>

    /**
     * One-shot fetch used by pull-to-refresh. Mirrors the same query
     * [observeNotifications] uses on subscribe.
     */
    suspend fun refreshNotifications(userId: String): Result<List<Notification>>

    /** Mark a single notification read (UPDATE read_at = now()). */
    suspend fun markRead(id: String): Result<Unit>

    /** Mark every unread notification owned by the user as read. */
    suspend fun markAllRead(userId: String): Result<Unit>
}
