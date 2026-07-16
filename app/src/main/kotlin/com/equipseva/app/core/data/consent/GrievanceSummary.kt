package com.equipseva.app.core.data.consent

/**
 * Human label for a DPDP grievance_type (round 485). The server keys are
 * already self-descriptive snake_case (access_request, deletion_request, …),
 * so the de-snaked Title-case fallback reads well; a few are spelled out for
 * polish. Unknown types degrade gracefully rather than showing a raw token.
 */
internal fun grievanceTypeLabel(type: String): String = when (type) {
    "access_request" -> "Data access request"
    "deletion_request" -> "Data deletion request"
    "correction_request" -> "Data correction request"
    "consent_withdrawal" -> "Consent withdrawal"
    "data_portability" -> "Data portability request"
    "complaint" -> "Complaint"
    "breach_report" -> "Data breach report"
    "nomination" -> "Nominee request"
    else -> type.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/**
 * DPDP grievance types a user can file (round 485 grievance_type CHECK,
 * user-facing subset — excludes the breach-notification path). Order = the
 * order shown in the filing form.
 */
internal val FILABLE_GRIEVANCE_TYPES: List<String> = listOf(
    "access_request",
    "correction_request",
    "deletion_request",
    "data_portability",
    "consent_withdrawal",
    "complaint",
)

/**
 * Client-side validation mirroring the server (file_dpdp_grievance requires a
 * trimmed description of at least 10 chars; the table caps it at 5000).
 * Returns an error message, or null when the description is acceptable.
 */
internal fun grievanceDescriptionError(description: String): String? {
    val len = description.trim().length
    return when {
        len == 0 -> "Please describe your request."
        len < 10 -> "Add a bit more detail (at least 10 characters)."
        len > 5000 -> "Keep it under 5000 characters."
        else -> null
    }
}
