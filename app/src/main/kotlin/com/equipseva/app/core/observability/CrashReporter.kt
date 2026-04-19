package com.equipseva.app.core.observability

import com.google.firebase.crashlytics.FirebaseCrashlytics
import io.sentry.Sentry
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Single entry point for non-fatal error reporting. Both Crashlytics and Sentry get the
 * report so we don't have two split bug-investigation paths during the early launch period.
 *
 * All user-supplied strings and throwable messages pass through [CrashDataScrubber] first so
 * emails / JWTs / Razorpay ids never leak into dashboards.
 */
@Singleton
class CrashReporter @Inject constructor() {

    fun report(throwable: Throwable, message: String? = null) {
        val safeMessage = CrashDataScrubber.scrub(message)
        val safeThrowable = wrapScrubbed(throwable)

        safeMessage?.let {
            FirebaseCrashlytics.getInstance().log(it)
            Sentry.addBreadcrumb(it)
        }
        FirebaseCrashlytics.getInstance().recordException(safeThrowable)
        Sentry.captureException(safeThrowable)
    }

    fun setUser(userId: String?) {
        // user id is the Supabase uuid — safe to attach as-is; it carries no PII on its own.
        FirebaseCrashlytics.getInstance().setUserId(userId.orEmpty())
        Sentry.setUser(userId?.let { io.sentry.protocol.User().apply { id = it } })
    }

    private fun wrapScrubbed(t: Throwable): Throwable {
        val scrubbedMessage = CrashDataScrubber.scrub(t.message)
        if (scrubbedMessage == t.message) return t
        // Preserve the original class + stack trace while swapping in a scrubbed message.
        // Crashlytics uses the message via toString(); Sentry reads the class + message.
        return ScrubbedException(t::class.java.name, scrubbedMessage, t)
    }

    /** Carrier exception whose message has been scrubbed. The original is kept as `cause`. */
    class ScrubbedException(
        private val originalType: String,
        override val message: String?,
        cause: Throwable,
    ) : RuntimeException(message, cause) {
        override fun toString(): String = "$originalType: ${message.orEmpty()}"
    }
}
