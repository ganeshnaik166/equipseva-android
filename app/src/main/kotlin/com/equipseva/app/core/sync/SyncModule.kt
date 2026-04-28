package com.equipseva.app.core.sync

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object SyncModule {

    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager =
        WorkManager.getInstance(context)

    @Provides
    @Singleton
    fun provideOutboxScheduler(workManager: WorkManager): OutboxScheduler =
        OutboxScheduler(workManager)
}

class OutboxScheduler(private val workManager: WorkManager) {
    fun schedulePeriodic() {
        val request = PeriodicWorkRequestBuilder<OutboxWorker>(15, TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .build()
        workManager.enqueueUniquePeriodicWork(
            OutboxWorker.UNIQUE_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    /**
     * Sign-out cleanup. Cancels both the periodic 15-minute drain and any
     * pending one-shot drain enqueued by [OutboxEnqueuer]. Without this,
     * after sign-out the worker would keep firing every 15 minutes against
     * an empty queue (handlers would still owner-gate, but the runner
     * cycles + log noise are wasted). Re-scheduled by EquipSevaApplication
     * on next sign-in.
     */
    fun cancelAll() {
        workManager.cancelUniqueWork(OutboxWorker.UNIQUE_NAME)
        workManager.cancelUniqueWork(OutboxWorker.UNIQUE_NAME + "-oneshot")
    }
}
