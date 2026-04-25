package com.equipseva.app.core.observability

import android.content.Context
import com.equipseva.app.BuildConfig
import com.equipseva.app.core.util.BuildConfigValues
import io.sentry.Breadcrumb
import io.sentry.SentryEvent
import io.sentry.SentryOptions
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
            // Crash-free SLO: turn on auto session tracking so sessions land
            // alongside crashes and crash-free % becomes computable. 30s
            // background-foreground gap matches Sentry's default for "new
            // session". (PENDING.md #47)
            options.isEnableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30_000
            options.tracesSampleRate = if (BuildConfig.DEBUG) 0.0 else 0.1
            options.isAttachScreenshot = false
            options.isAttachViewHierarchy = false
            options.isEnableUserInteractionBreadcrumbs = true
            options.isEnableUserInteractionTracing = false
            // Do not let Sentry add "data" fields that may contain tokens
            // and don't ship default PII (IPs, emails).
            options.isSendDefaultPii = false
            options.beforeSend = SentryOptions.BeforeSendCallback { event, _ -> scrubEvent(event) }
            options.beforeBreadcrumb = SentryOptions.BeforeBreadcrumbCallback { crumb, _ -> scrubCrumb(crumb) }
        }
    }

    private fun scrubEvent(event: SentryEvent): SentryEvent {
        event.message?.let { m ->
            m.message = CrashDataScrubber.scrub(m.message)
            m.formatted = CrashDataScrubber.scrub(m.formatted)
        }
        event.throwable?.let { t ->
            // Sentry renders the throwable chain from `exceptions`; scrub each message in place.
            event.exceptions?.forEach { ex -> ex.value = CrashDataScrubber.scrub(ex.value) }
            // Best-effort guard for frameworks that stash sensitive strings in extras.
            val scrubbed = CrashDataScrubber.scrubThrowableMessage(t)
            if (scrubbed != t.message) {
                event.setExtra("original_message_redacted", "true")
            }
        }
        return event
    }

    private fun scrubCrumb(crumb: Breadcrumb): Breadcrumb? {
        crumb.message = CrashDataScrubber.scrub(crumb.message)
        // Drop high-volume HTTP breadcrumbs that touch auth — URLs + bodies there routinely
        // carry JWTs. Keep non-auth http breadcrumbs (with scrubbed message).
        val url = crumb.getData("url")?.toString().orEmpty()
        if (crumb.category == "http" && url.contains("/auth/v1/")) return null
        return crumb
    }
}
