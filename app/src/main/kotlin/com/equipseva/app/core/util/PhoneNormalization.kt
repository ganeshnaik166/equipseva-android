package com.equipseva.app.core.util

/**
 * Normalizes user input into the canonical India mobile E.164 form (+91 + 10 digits).
 *
 * Hands user-typed / pasted phone strings the smallest reasonable transform:
 *   - keep a single leading '+'
 *   - drop any non-ASCII digits (Devanagari / Arabic numerals would break
 *     Supabase auth's E.164 parser)
 *   - cap at 16 chars (E.164 max + buffer)
 *   - if input starts with `+9191` AND the dedup result is exactly 13 chars,
 *     strip the duplicate `+91` prefix (round 287 — guard against double-
 *     prefix from paste-on-top-of-autoprefix); otherwise leave malformed
 *     input visible so the user notices.
 */
fun normalizeIndiaMobileInput(value: String): String {
    var cleaned = value
        .filterIndexed { i, c -> (i == 0 && c == '+') || c in '0'..'9' }
        .take(16)
    if (cleaned.startsWith("+9191") && cleaned.length > 13) {
        val candidate = "+91" + cleaned.substring(5)
        if (candidate.length == 13) {
            cleaned = candidate
        }
    }
    return cleaned
}
