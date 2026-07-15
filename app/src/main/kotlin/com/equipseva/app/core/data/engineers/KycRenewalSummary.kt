package com.equipseva.app.core.data.engineers

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Urgency band for a re-KYC cycle from `days_until_due` (negative = past the
 * due date, into the grace window). Pinned cut-points:
 *   * `overdue`   — days < 0 (past due; verification will lapse at grace end)
 *   * `due_soon`  — 0 ≤ days ≤ 14
 *   * `scheduled` — days > 14
 * These drive the nudge pill (Danger / Warn / Info).
 */
internal fun renewalUrgency(daysUntilDue: Double): String = when {
    daysUntilDue < 0.0 -> "overdue"
    daysUntilDue <= 14.0 -> "due_soon"
    else -> "scheduled"
}

/**
 * Human "when" line from `days_until_due` (fractional, negative = overdue).
 * Within half a day of zero reads "Due today"; else rounds to whole days,
 * singular/plural handled.
 */
internal fun formatRenewalDue(daysUntilDue: Double): String {
    if (daysUntilDue <= -0.5) {
        val n = abs(daysUntilDue).roundToInt()
        return "Overdue by $n day${if (n == 1) "" else "s"}"
    }
    if (daysUntilDue < 0.5) return "Due today"
    val n = daysUntilDue.roundToInt()
    return "Due in $n day${if (n == 1) "" else "s"}"
}

/**
 * Human label for a re-KYC checklist item key. Unknown keys degrade to a
 * de-snaked Title-case fallback so a new server item never renders a raw
 * token. Mirrors the KYC document set the engineer originally submitted.
 */
internal fun renewalItemLabel(key: String): String = when (key) {
    "aadhaar" -> "Aadhaar"
    "pan" -> "PAN"
    "police_verification" -> "Police verification"
    "certificate", "certificates", "qualification_certificate" -> "Qualification certificate"
    "profile_photo", "photo", "selfie" -> "Profile photo / selfie"
    "address_proof" -> "Address proof"
    else -> key.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
