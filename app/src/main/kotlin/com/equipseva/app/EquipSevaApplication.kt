package com.equipseva.app

import android.app.Application
import android.util.Log
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.equipseva.app.core.observability.SentryInitializer
import com.equipseva.app.core.observability.SentryUserBridge
import com.equipseva.app.core.observability.StartupTelemetry
import com.equipseva.app.core.push.NotificationChannels
import com.equipseva.app.core.security.DeviceIntegrityCheck
import com.equipseva.app.core.security.SignatureVerifier
import com.equipseva.app.core.security.TamperPolicy
import com.equipseva.app.core.sync.OutboxScheduler
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class EquipSevaApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var sentryInitializer: SentryInitializer
    @Inject lateinit var sentryUserBridge: SentryUserBridge
    @Inject lateinit var outboxScheduler: OutboxScheduler
    @Inject lateinit var tamperPolicy: TamperPolicy

    override fun onCreate() {
        super.onCreate()
        // Sentry must init before StartupTelemetry.markStart() so the
        // cold-start transaction lands on a real hub rather than a NoOp
        // (assuming a DSN is wired). When DSN is blank both paths NoOp.
        sentryInitializer.init(this)
        // Mirror auth state into Sentry user scope (user_id only). Safe before
        // or after init() — bridge no-ops when DSN is blank.
        sentryUserBridge.attach()
        StartupTelemetry.markStart()
        NotificationChannels.register(this)
        // Periodic 15-minute drain of the offline outbox. Without this,
        // queued writes only flush via the one-shot piggybacked onto each
        // enqueue() call — a user who queued a write offline, killed the
        // app, then came back online days later would never see it sync
        // until they triggered another write. Cancelled on sign-out by
        // [OutboxScheduler.cancelAll].
        outboxScheduler.schedulePeriodic()

        // Anti-tamper signals captured once at boot and routed through
        // [TamperPolicy.enforce] for any sensitive action (auth mutations,
        // delete account, KYC submit). Today the signature signal only denies
        // when EXPECTED_CERT_SHA256 is wired (see PENDING.md #14); the device
        // integrity signal is informational until v2.
        val sigVerdict = SignatureVerifier.verify(this)
        val devVerdict = DeviceIntegrityCheck.run()
        tamperPolicy.setSignatureVerdict(sigVerdict)
        Log.i(TAG, "Integrity boot: sig=$sigVerdict ${devVerdict.toTag()}")
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    private companion object {
        const val TAG = "EquipSevaApplication"
    }
}
