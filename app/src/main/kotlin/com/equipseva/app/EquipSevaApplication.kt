package com.equipseva.app

import android.app.Application
import android.util.Log
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.disk.DiskCache
import coil3.disk.directory
import coil3.memory.MemoryCache
import coil3.request.crossfade
import com.equipseva.app.core.observability.CrashlyticsUserBridge
import com.equipseva.app.core.observability.SentryInitializer
import com.equipseva.app.core.observability.SentryUserBridge
import com.equipseva.app.core.observability.StartupTelemetry
import com.equipseva.app.core.payments.PendingAmcPaymentsReconciler
import com.equipseva.app.core.payments.PendingEscrowPaymentsReconciler
import com.equipseva.app.core.push.NotificationChannels
import com.equipseva.app.core.security.DeviceIntegrityCheck
import com.equipseva.app.core.security.InstallSourceVerifier
import com.equipseva.app.core.security.IntegritySnapshot
import com.equipseva.app.core.security.ReverseEngineeringDetector
import com.equipseva.app.core.security.SignatureVerifier
import com.equipseva.app.core.sync.OutboxScheduler
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@HiltAndroidApp
class EquipSevaApplication : Application(), Configuration.Provider, SingletonImageLoader.Factory {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var sentryInitializer: SentryInitializer
    @Inject lateinit var sentryUserBridge: SentryUserBridge
    @Inject lateinit var crashlyticsUserBridge: CrashlyticsUserBridge
    @Inject lateinit var outboxScheduler: OutboxScheduler
    @Inject lateinit var pendingPaymentsReconciler: PendingAmcPaymentsReconciler
    @Inject lateinit var pendingEscrowPaymentsReconciler: PendingEscrowPaymentsReconciler

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        // Sentry must init before StartupTelemetry.markStart() so the
        // cold-start transaction lands on a real hub rather than a NoOp
        // (assuming a DSN is wired). When DSN is blank both paths NoOp.
        sentryInitializer.init(this)
        // Mirror auth state into Sentry user scope (user_id only). Safe before
        // or after init() — bridge no-ops when DSN is blank.
        sentryUserBridge.attach()
        // Mirror the same into Crashlytics. Without this, every crash
        // report carried an empty user id — Crashlytics's "Affected
        // users" stayed at zero and per-user filtering was impossible.
        crashlyticsUserBridge.attach()
        StartupTelemetry.markStart()
        NotificationChannels.register(this)
        // Periodic 15-minute drain of the offline outbox. Without this,
        // queued writes only flush via the one-shot piggybacked onto each
        // enqueue() call — a user who queued a write offline, killed the
        // app, then came back online days later would never see it sync
        // until they triggered another write. Cancelled on sign-out by
        // [OutboxScheduler.cancelAll].
        outboxScheduler.schedulePeriodic()

        // Round 234 — Razorpay process-death recovery. Reconciles any
        // AMC payment order ids we wrote to local storage before the
        // SDK's checkout activity but never cleared because the OS
        // killed our process mid-flow. Fire-and-forget; the reconciler
        // swallows network errors and retries on next cold-start.
        // Round 237 — wrap in runCatching so an unexpected throw from
        // the reconciler can't kill the appScope's SupervisorJob root
        // and block downstream coroutines launched on the same scope.
        appScope.launch {
            runCatching { pendingPaymentsReconciler.reconcile() }
                .onFailure { Log.e(TAG, "pending payments reconcile failed", it) }
        }

        // Round 280 — sibling reconcile for repair-job escrow payments.
        // Same process-death scenario: user paid via Razorpay but the
        // OS killed the app before verify-repair-job-payment fired. The
        // escrow row stays 'pending' on the server; without this sweep
        // the home banner's marker would linger forever even after the
        // hospital recovered by re-paying or contacting support.
        appScope.launch {
            runCatching { pendingEscrowPaymentsReconciler.reconcile() }
                .onFailure { Log.e(TAG, "pending escrow payments reconcile failed", it) }
        }

        // Anti-tamper signature check. Stays report-only until the user
        // sets BuildConfig.TAMPER_ENFORCE=true (after both upload-key and
        // Play App Signing SHAs are wired into EXPECTED_CERT_SHA256 per
        // runbook §5c) — flipping enforce before Play SHA is added would
        // hard-exit every Play-distributed install.
        val sigVerdict = SignatureVerifier.verify(this)
        val devVerdict = DeviceIntegrityCheck.run(this)
        val installVerdict = InstallSourceVerifier.verify(this)
        val reVerdict = ReverseEngineeringDetector.scan(this)
        IntegritySnapshot.capture(this, sigVerdict, installVerdict, devVerdict, reVerdict)
        Log.i(TAG, "Integrity boot: sig=$sigVerdict install=$installVerdict reTools=${reVerdict.foundPackages.size} ${devVerdict.toTag()}")

        // Hard-block conditions when TAMPER_ENFORCE=true:
        //   1. Cert SHA mismatch — APK was re-signed
        //   2. Install came from a non-Google-Play installer in a release
        //      build — sideloaded tampered APK, or store-fronted clone
        //   3. Known reverse-engineering / hooking tool present —
        //      Xposed/LSPosed/Magisk-manager/Frida/Lucky Patcher
        // Debug builds skip 2+3 unconditionally so devs can ADB-install.
        val installBlocked = !BuildConfig.DEBUG && installVerdict == InstallSourceVerifier.Verdict.Sideloaded
        val reBlocked = !BuildConfig.DEBUG && !reVerdict.clean
        if (BuildConfig.TAMPER_ENFORCE && (sigVerdict == SignatureVerifier.Verdict.Tampered || installBlocked || reBlocked)) {
            Log.e(TAG, "Refusing to start: sig=$sigVerdict install=$installVerdict reTools=${reVerdict.foundPackages}")
            // Hard-exit before any auth / network / repository code runs.
            // The Supabase session is encrypted at rest via the custom
            // EncryptedSessionManager (Keystore-backed AES256/GCM); an
            // attacker re-signing the APK would need to either:
            //   1. install the new APK alongside the genuine one (different
            //      package id) — the encrypted session in the genuine
            //      app's sandbox isn't readable from the tampered package
            //   2. uninstall the genuine app first, wiping prefs entirely
            // Either way, no separate session-wipe is needed on tamper
            // detection — the encryption + sandbox isolation already
            // protect the tokens.
            android.os.Process.killProcess(android.os.Process.myPid())
            kotlin.system.exitProcess(0)
        }

        // r845 — periodic re-verification. Defense layer against an
        // attacker who patched the one if-block above: this coroutine
        // re-runs the same checks every 15 minutes and exits the process
        // if any verdict flips dirty. To bypass, the attacker now has to
        // find AND patch this loop too. R8 inlines + obfuscates so the
        // call sites don't share an obvious symbol; the loop body is
        // also intentionally duplicated rather than calling a shared
        // helper.
        appScope.launch {
            while (true) {
                kotlinx.coroutines.delay(15L * 60 * 1000)
                val sig = SignatureVerifier.verify(this@EquipSevaApplication)
                val install = InstallSourceVerifier.verify(this@EquipSevaApplication)
                val re = ReverseEngineeringDetector.scan(this@EquipSevaApplication)
                val dev = DeviceIntegrityCheck.run(this@EquipSevaApplication)
                IntegritySnapshot.capture(this@EquipSevaApplication, sig, install, dev, re)
                val blockNow = !BuildConfig.DEBUG && (
                    sig == SignatureVerifier.Verdict.Tampered ||
                        install == InstallSourceVerifier.Verdict.Sideloaded ||
                        !re.clean
                    )
                if (BuildConfig.TAMPER_ENFORCE && blockNow) {
                    Log.e(TAG, "Periodic integrity check failed — exiting: sig=$sig install=$install re=${re.foundPackages}")
                    android.os.Process.killProcess(android.os.Process.myPid())
                    kotlin.system.exitProcess(0)
                }
            }
        }
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    /**
     * Configure the singleton Coil ImageLoader.
     *
     * Coil's defaults are tuned for high-end Pixels (25% of available
     * heap for memory cache, no disk cache by default on Coil 3.x).
     * On the low-end Realme/Samsung devices we ship to, a screen of
     * engineer avatars + a chat with image attachments can race the
     * heap cap and OOM. Pinning explicit byte sizes gives us
     * predictable footprint regardless of device class.
     *
     * The disk cache also matters: without it, every cold start
     * re-downloads engineer avatars + KYC thumbnails over the user's
     * data, even though the Supabase signed URLs are byte-identical
     * for the cache-control lifetime.
     */
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .crossfade(true)
            .memoryCache {
                MemoryCache.Builder()
                    .maxSizeBytes(64L * 1024 * 1024)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizeBytes(50L * 1024 * 1024)
                    .build()
            }
            .build()

    private companion object {
        const val TAG = "EquipSevaApplication"
    }
}
