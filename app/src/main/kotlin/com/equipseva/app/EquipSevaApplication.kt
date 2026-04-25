package com.equipseva.app

import android.app.Application
import android.util.Log
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.equipseva.app.core.data.cart.CartSyncBootstrap
import com.equipseva.app.core.observability.SentryInitializer
import com.equipseva.app.core.observability.SentryUserBridge
import com.equipseva.app.core.observability.StartupTelemetry
import com.equipseva.app.core.push.NotificationChannels
import com.equipseva.app.core.security.DeviceIntegrityCheck
import com.equipseva.app.core.security.SignatureVerifier
import com.razorpay.Checkout
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class EquipSevaApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var sentryInitializer: SentryInitializer
    @Inject lateinit var sentryUserBridge: SentryUserBridge
    @Inject lateinit var cartSyncBootstrap: CartSyncBootstrap

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
        // Warm the Razorpay WebView so the first checkout tap isn't blocked on asset load.
        Checkout.preload(applicationContext)

        // Reconcile the server-side cart into Room once per session start so
        // the basket survives reinstall and roams across devices. Mutations
        // after this initial pull drain through the CART_MUTATION outbox.
        cartSyncBootstrap.start()

        // Report-only anti-tamper: log signals on boot. Enforcement (wipe
        // session + show "not authorized" screen) flips on once the release
        // keystore lands and EXPECTED_CERT_SHA256 is filled in, and once the
        // server-side Play Integrity verify endpoint ships.
        val sigVerdict = SignatureVerifier.verify(this)
        val devVerdict = DeviceIntegrityCheck.run()
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
