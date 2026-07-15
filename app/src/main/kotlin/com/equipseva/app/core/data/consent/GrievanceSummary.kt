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
    "breach_report" -> "Data breach report"
    "nomination" -> "Nominee request"
    else -> type.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
