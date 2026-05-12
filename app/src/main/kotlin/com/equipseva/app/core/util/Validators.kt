package com.equipseva.app.core.util

object Validators {

    // Anchored — covers the 99% case without trying to be RFC 5322.
    // `%` is allowed in the local part per RFC for forwarding/plus-tag use.
    private val EMAIL_REGEX = Regex(
        "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$",
    )

    fun emailIsValid(email: String): Boolean =
        email.isNotBlank() && EMAIL_REGEX.matches(email.trim())

    /**
     * Minimum strength: 8+ chars, at least one letter and one digit.
     * Stricter than Supabase's default to avoid easy-guess accounts in healthcare context.
     */
    fun passwordIsStrong(password: String): Boolean {
        if (password.length < 8) return false
        val hasLetter = password.any { it.isLetter() }
        val hasDigit = password.any { it.isDigit() }
        return hasLetter && hasDigit
    }

    fun passwordWeakness(password: String): String? = when {
        password.length < 8 -> "Use at least 8 characters"
        password.none { it.isLetter() } -> "Include at least one letter"
        password.none { it.isDigit() } -> "Include at least one number"
        else -> null
    }

    // GSTIN: 15 chars · 2-digit state · 10-char PAN · 1 entity digit · 'Z' · 1 alphanumeric check.
    // Source: https://gst.gov.in/help (GSTIN format spec).
    private val GSTIN_REGEX = Regex("^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$")

    /** Empty = not required at this layer; non-empty must match the canonical GSTIN shape. */
    fun gstinError(value: String): String? {
        val v = value.trim().uppercase()
        if (v.isEmpty()) return null
        if (v.length != 15) return "GSTIN must be exactly 15 characters"
        if (!GSTIN_REGEX.matches(v)) return "Invalid GSTIN format"
        return null
    }
}
