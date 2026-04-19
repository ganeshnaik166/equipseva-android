package com.equipseva.app.core.observability

/**
 * Replaces email addresses, JWTs, Razorpay identifiers, and Supabase URLs with `[redacted]`
 * before exception messages and breadcrumbs are sent to Sentry / Crashlytics. The patterns
 * are deliberately loose — false positives redact more than needed, which is safe; false
 * negatives leak PII, which is not.
 *
 * Pure Kotlin so it is trivially unit-testable without Android deps.
 */
object CrashDataScrubber {

    private val patterns: List<Regex> = listOf(
        // Email
        Regex("""[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"""),
        // Supabase / other JWTs start with "eyJ" and are dot-separated base64url segments.
        Regex("""eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"""),
        // Razorpay ids: order_..., pay_..., rpay_... (prod ids are ~14 chars; keep threshold
        // loose at 4+ so short test ids are still redacted).
        Regex("""\b(?:order|pay|rpay)_[A-Za-z0-9]{4,}\b"""),
        // Supabase storage signed-url tokens sometimes appear in exception messages.
        Regex("""[?&]token=[A-Za-z0-9._\-]+"""),
        // Authorization headers leaked via HTTP exceptions.
        Regex("""(?i)authorization:\s*bearer\s+[A-Za-z0-9._\-]+"""),
    )

    fun scrub(input: String?): String? {
        if (input.isNullOrEmpty()) return input
        return patterns.fold(input) { acc, re -> re.replace(acc, "[redacted]") }
    }

    fun scrubThrowableMessage(t: Throwable): String? = scrub(t.message)
}
