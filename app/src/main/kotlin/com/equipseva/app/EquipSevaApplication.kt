package com.equipseva.app

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.equipseva.app.core.observability.SentryInitializer
import com.equipseva.app.core.push.NotificationChannels
import com.razorpay.Checkout
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class EquipSevaApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var sentryInitializer: SentryInitializer

    override fun onCreate() {
        super.onCreate()
        sentryInitializer.init(this)
        NotificationChannels.register(this)
        // Warm the Razorpay WebView so the first checkout tap isn't blocked on asset load.
        Checkout.preload(applicationContext)
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}
