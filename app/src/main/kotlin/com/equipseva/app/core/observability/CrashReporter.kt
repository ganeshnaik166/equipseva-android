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

    private fun wrapScrubbed(t: Throwable): Throwable = wrapScrubbedThrowable(t)
}

/** Carrier exception whose message has been scrubbed. */
class ScrubbedException(
    private val originalType: String,
    override val message: String?,
    cause: Throwable? = null,
) : RuntimeException(message, cause) {
    override fun toString(): String = "$originalType: ${message.orEmpty()}"
}

/**
 * Renders [t] in a form that is safe to hand to the Crashlytics / Sentry
 * dashboards.
 *
 *  * A lone throwable whose message [CrashDataScrubber.scrub] left
 *    unchanged rides as itself. Preserving the original Throwable identity
 *    (class + stack trace) makes the dashboard cluster the exception with
 *    sibling reports of the same kind.
 *  * Anything else is rebuilt as a chain of [ScrubbedException] copies —
 *    original class name, scrubbed message, original stack trace — with no
 *    reference to the originals anywhere in it. Both reporters serialise
 *    the whole cause chain, so a wrapper that kept the original as its
 *    `cause` shipped the raw message it had just redacted, and a
 *    PII-bearing cause under a clean top-level message was never looked at
 *    at all. Repository code wrapping a supabase-kt `RestException` (whose
 *    message embeds the request URL, tokens included) is the common shape.
 *
 * Pure / pinable so the redaction guarantee survives any future refactor
 * of [CrashReporter].
 */
internal fun wrapScrubbedThrowable(t: Throwable): Throwable {
    if (t.cause == null && CrashDataScrubber.scrub(t.message) == t.message) return t
    return scrubbedCauseChain(t)
}

/**
 * Rebuilds [t] and every cause beneath it as scrubbed copies, linked
 * bottom-up so no original instance is reachable from the result.
 *
 * The walk is identity-guarded and depth-capped: a throwable whose cause
 * cycles back to itself is legal on the JVM (`initCause` is only checked
 * for self-reference at depth 1) and would otherwise loop forever.
 */
internal fun scrubbedCauseChain(t: Throwable): Throwable {
    val chain = mutableListOf<Throwable>()
    var link: Throwable? = t
    while (link != null && chain.size < MAX_SCRUBBED_CHAIN_DEPTH && chain.none { it === link }) {
        chain.add(link)
        link = link.cause
    }
    var rebuilt: Throwable? = null
    for (original in chain.asReversed()) {
        rebuilt = ScrubbedException(
            originalType = original::class.java.name,
            message = CrashDataScrubber.scrub(original.message),
            cause = rebuilt,
        ).apply { setStackTrace(original.stackTrace) }
    }
    return rebuilt ?: t
}

/** Deeper chains are already unreadable in a dashboard; the cap also bounds a cause cycle. */
private const val MAX_SCRUBBED_CHAIN_DEPTH = 16
