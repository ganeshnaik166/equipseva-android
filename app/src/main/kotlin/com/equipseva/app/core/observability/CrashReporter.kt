package com.equipseva.app.core.observability

import com.google.firebase.crashlytics.FirebaseCrashlytics
import io.sentry.Sentry
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Single entry point for non-fatal error reporting. Both Crashlytics and Sentry get the
 * report so we don't have two split bug-investigation paths during the early launch period.
 */
@Singleton
class CrashReporter @Inject constructor() {

    fun report(throwable: Throwable, message: String? = null) {
        message?.let {
            FirebaseCrashlytics.getInstance().log(it)
            Sentry.addBreadcrumb(it)
        }
        FirebaseCrashlytics.getInstance().recordException(throwable)
        Sentry.captureException(throwable)
    }

    fun setUser(userId: String?) {
        FirebaseCrashlytics.getInstance().setUserId(userId.orEmpty())
        Sentry.setUser(userId?.let { io.sentry.protocol.User().apply { id = it } })
    }
}
