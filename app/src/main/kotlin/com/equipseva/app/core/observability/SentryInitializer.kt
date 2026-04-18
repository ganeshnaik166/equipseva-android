package com.equipseva.app.core.observability

import android.content.Context
import com.equipseva.app.BuildConfig
import com.equipseva.app.core.util.BuildConfigValues
import io.sentry.android.core.SentryAndroid
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SentryInitializer @Inject constructor() {

    fun init(context: Context) {
        val dsn = BuildConfigValues.sentryDsn
        if (dsn.isBlank()) return
        SentryAndroid.init(context) { options ->
            options.dsn = dsn
            options.environment = if (BuildConfig.DEBUG) "debug" else "release"
            options.release = "${BuildConfig.APPLICATION_ID}@${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}"
            options.tracesSampleRate = if (BuildConfig.DEBUG) 1.0 else 0.2
            options.isEnableUserInteractionTracing = true
            options.isAttachScreenshot = false
            options.isAttachViewHierarchy = false
        }
    }
}
