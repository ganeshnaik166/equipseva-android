package com.equipseva.app.core.sync

import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Thin injection seam for features that need to queue a write for later retry.
 * Hides the [OutboxDao] + [WorkManager] wiring so each feature just produces a
 * kind + JSON payload and calls [enqueue]. The enqueuer immediately kicks a
 * one-shot flush so a transient network hiccup recovers in seconds, not at the
 * next 15-minute periodic tick.
 */
@Singleton
class OutboxEnqueuer @Inject constructor(
    private val outboxDao: OutboxDao,
    private val workManager: WorkManager,
) {
    suspend fun enqueue(kind: String, payloadJson: String) {
        outboxDao.enqueue(
            OutboxEntryEntity(
                kind = kind,
                payload = payloadJson,
                createdAt = System.currentTimeMillis(),
            ),
        )
        val request = OneTimeWorkRequestBuilder<OutboxWorker>().build()
        workManager.enqueueUniqueWork(
            OutboxWorker.UNIQUE_NAME + "-oneshot",
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }
}
