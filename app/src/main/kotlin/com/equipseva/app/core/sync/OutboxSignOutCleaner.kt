package com.equipseva.app.core.sync

import androidx.room.withTransaction
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.core.data.AppDatabase
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/**
 * Keeps stale cleanup from deleting a successor login's committed outbox work.
 * Historical rows and ordinary producers/readers remain unowned; this is a
 * deletion boundary, not general account isolation.
 */
@Singleton
class OutboxSignOutCleaner @Inject constructor(
    private val database: AppDatabase,
    private val ownership: LocalSessionOwnership,
) {
    suspend fun clearForSignOut(ticket: LocalSessionOwnership.Ticket?) {
        database.withTransaction {
            // SQLite admission can block even after the caller is cancelled.
            currentCoroutineContext().ensureActive()
            // Check only after taking the real write transaction. That transaction
            // serializes competing enqueues across the suspend DAO delete; the
            // ownership monitor need not stay locked while database work runs.
            if (ownership.withCurrent(ticket) {}) {
                database.outboxDao().clearAll()
            }
        }
    }
}
