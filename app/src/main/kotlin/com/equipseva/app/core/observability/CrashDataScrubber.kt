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
        // Indian PII surfaced via KYC flows — DPDP requires keeping these out of telemetry.
        // Indian mobile: optional +91 / 0 prefix + 10 digits starting 6-9. Run before
        // Aadhaar so a `+91` mobile isn't partially redacted by the 12-digit Aadhaar regex.
        Regex("""(?<![+\d])(?:\+?91[\s-]?|0)?[6-9]\d{9}(?!\d)"""),
        // Aadhaar: 12 digits, optionally space/dash-grouped 4-4-4.
        Regex("""(?<![+\d])\d{4}[\s-]?\d{4}[\s-]?\d{4}(?!\d)"""),
        // GSTIN: 2-digit state + 10-char PAN + 1 entity + Z + 1 checksum (run before PAN
        // so the embedded PAN substring isn't redacted first and break the GSTIN match).
        Regex("""\b\d{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]\b"""),
        // PAN: 5 letters + 4 digits + 1 letter.
        Regex("""\b[A-Z]{5}[0-9]{4}[A-Z]\b"""),
    )

    fun scrub(input: String?): String? {
        if (input.isNullOrEmpty()) return input
        return patterns.fold(input) { acc, re -> re.replace(acc, "[redacted]") }
    }

    fun scrubThrowableMessage(t: Throwable): String? = scrub(t.message)
}
