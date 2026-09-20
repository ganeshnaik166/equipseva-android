package com.equipseva.app.core.sync

import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.core.data.AppDatabase
import javax.inject.Inject
import javax.inject.Singleton

/** Cleanup adapter; initial test-first scaffold retains the existing deletion. */
@Singleton
class OutboxSignOutCleaner @Inject constructor(
    private val database: AppDatabase,
    private val ownership: LocalSessionOwnership,
) {
    suspend fun clearForSignOut(ticket: LocalSessionOwnership.Ticket?) {
        database.outboxDao().clearAll()
    }
}
