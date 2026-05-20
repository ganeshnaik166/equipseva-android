package com.equipseva.app.core.util

object Validators {

    // Anchored — covers the 99% case without trying to be RFC 5322.
    // `%` is allowed in the local part per RFC for forwarding/plus-tag use.
    // Domain side requires each label to start AND end with an alphanumeric
    // (so `test@.com`, `test@-foo.com`, and `test@foo-.com` are rejected),
    // plus a final TLD of at least two ASCII letters. The older regex
    // (`[A-Za-z0-9.-]+\\.[A-Za-z]{2,}`) accepted leading-dot / leading-hyphen
    // garbage that PostgreSQL then stored verbatim.
    private val EMAIL_REGEX = Regex(
        "^[A-Za-z0-9._%+-]+@" +
            "[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?" +
            "(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*" +
            "\\.[A-Za-z]{2,}$",
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

    // Round 441 — Indian mobile-shape check for the optional secondary
    // phone fields (hospital reception, biomed contact). The primary
    // sign-in / KYC phone path uses normalizeIndiaMobileInput +
    // AddPhoneScreen dedup (r287). For form fields where the user
    // types freely, accept either "+91" + 10 digits or just 10 digits
    // starting 6-9 (India mobile prefix range).
    private val INDIA_MOBILE_DIGITS = Regex("^[6-9][0-9]{9}$")

    /** Empty = not required at this layer; non-empty must match the India mobile shape. */
    fun indiaMobileError(value: String): String? {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        val digits = trimmed
            .removePrefix("+91")
            .removePrefix("+")
            .removePrefix("91")
            .filter { it.isDigit() }
        if (digits.length != 10) return "Enter 10 digits"
        if (!INDIA_MOBILE_DIGITS.matches(digits)) return "Indian mobile must start with 6, 7, 8, or 9"
        return null
    }

    // Round 441 — Indian pincode is exactly 6 digits, first digit 1-9.
    // Source: https://en.wikipedia.org/wiki/Postal_Index_Number
    private val PINCODE_REGEX = Regex("^[1-9][0-9]{5}$")

    /** Empty = not required at this layer; non-empty must be a 6-digit PIN. */
    fun pincodeError(value: String): String? {
        val v = value.trim()
        if (v.isEmpty()) return null
        if (v.length != 6) return "PIN code must be exactly 6 digits"
        if (!PINCODE_REGEX.matches(v)) return "Invalid PIN code"
        return null
    }
}
