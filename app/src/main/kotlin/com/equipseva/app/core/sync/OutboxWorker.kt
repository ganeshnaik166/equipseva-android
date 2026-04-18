package com.equipseva.app.core.sync

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.equipseva.app.core.data.dao.OutboxDao
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Drains the offline outbox. Real per-kind dispatch lands in Phase 3 — this scaffold
 * just iterates pending entries, leaves the actual network calls to the per-feature
 * implementations to wire when they land.
 */
@HiltWorker
class OutboxWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val outbox: OutboxDao,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val pending = outbox.nextBatch()
        if (pending.isEmpty()) return Result.success()
        // Phase-3 dispatch: route each entry by `kind` to its handler. For now, no-op success
        // so the worker plumbing can be exercised end-to-end without dropping data.
        return Result.success()
    }

    companion object {
        const val UNIQUE_NAME = "outbox-flush"
    }
}
