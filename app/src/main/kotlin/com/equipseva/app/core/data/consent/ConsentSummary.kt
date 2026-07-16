package com.equipseva.app.core.data.consent

/** A consent category with its rows, for the grouped consent-centre list. */
data class ConsentGroup(
    val categoryLabel: String,
    val rows: List<ConsentRepository.ConsentRow>,
)

/**
 * Human label for a consent_type (round 485's CHECK list). Unknown keys
 * degrade to a de-snaked Title-case fallback so a new server consent type
 * never renders a raw token.
 */
internal fun consentTypeLabel(type: String): String = when (type) {
    "terms_of_service" -> "Terms of Service"
    "privacy_policy" -> "Privacy Policy"
    "dpdp_data_processing" -> "Data processing (DPDP)"
    "cookies_essential" -> "Essential cookies"
    "cookies_analytics" -> "Analytics cookies"
    "marketing_emails" -> "Marketing emails"
    "marketing_push" -> "Marketing push notifications"
    "marketing_sms" -> "Marketing SMS"
    "whatsapp_business" -> "WhatsApp updates"
    "location_tracking" -> "Location tracking"
    "photo_upload" -> "Photo upload"
    "amc_auto_charge" -> "AMC auto-charge"
    else -> type.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/** Coarse category for a consent_type — drives grouping + section order. */
internal fun consentCategory(type: String): String = when (type) {
    "terms_of_service", "privacy_policy", "dpdp_data_processing" -> "legal"
    "cookies_essential", "cookies_analytics" -> "cookies"
    "marketing_emails", "marketing_push", "marketing_sms", "whatsapp_business" -> "marketing"
    "location_tracking", "photo_upload" -> "permissions"
    "amc_auto_charge" -> "billing"
    else -> "other"
}

internal fun consentCategoryLabel(category: String): String = when (category) {
    "legal" -> "Legal"
    "permissions" -> "Device permissions"
    "marketing" -> "Marketing"
    "billing" -> "Billing"
    "cookies" -> "Cookies"
    else -> "Other"
}

/**
 * Whether a consent type can be toggled (granted/withdrawn) from the consent
 * centre (r1418). Scoped to marketing / analytics / comms consents — safe to
 * opt in or out of at will. Legal + essential + permission/billing consents are
 * non-withdrawable in-app (managed via their own flows or the OS) and stay
 * read-only here.
 */
internal fun isWithdrawableConsent(type: String): Boolean = type in setOf(
    "marketing_emails",
    "marketing_push",
    "marketing_sms",
    "whatsapp_business",
    "cookies_analytics",
)

// Section order: the consents that matter most to a user's rights first.
private val CATEGORY_ORDER = listOf("legal", "permissions", "billing", "marketing", "cookies", "other")

/**
 * Groups consent rows by [consentCategory] into ordered [ConsentGroup]s
 * (legal → permissions → billing → marketing → cookies → other). Rows within
 * a group are ordered by their human label so the list is stable regardless
 * of server row order.
 */
internal fun groupConsents(rows: List<ConsentRepository.ConsentRow>): List<ConsentGroup> =
    rows.groupBy { consentCategory(it.consentType) }
        .toList()
        .sortedBy { (cat, _) -> CATEGORY_ORDER.indexOf(cat).let { if (it < 0) CATEGORY_ORDER.size else it } }
        .map { (cat, groupRows) ->
            ConsentGroup(
                categoryLabel = consentCategoryLabel(cat),
                rows = groupRows.sortedBy { consentTypeLabel(it.consentType) },
            )
        }
