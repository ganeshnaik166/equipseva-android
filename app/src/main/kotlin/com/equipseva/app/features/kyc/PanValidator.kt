package com.equipseva.app.features.kyc

/**
 * Shape-checks an Indian PAN (Permanent Account Number). PAN format is
 * exactly 10 chars: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F).
 *
 * This is a cheap client-side guard — it catches typos early but does NOT
 * verify the PAN is actually issued. Server-side verification via Karza /
 * Sandbox PAN-verify ships in v1.1; until then, admin reviews each PAN
 * manually against the uploaded card photo.
 */
internal object PanValidator {
    private val REGEX = Regex("^[A-Z]{5}[0-9]{4}[A-Z]$")

    fun isValid(pan: String): Boolean = REGEX.matches(pan)
}
