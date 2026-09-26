package com.equipseva.app.features.auth

/**
 * Public onboarding intent only; never a role, membership or entitlement.
 * [savedKey] belongs to a local registration draft, not a backend authorization payload.
 */
internal enum class PublicRegistrationIntent(val savedKey: String) {
    BIOMEDICAL_ENGINEER("biomedical_engineer"),
    HOSPITAL("hospital"),
    ENGINEERING_ORGANISATION("engineering_organisation");

    companion object {
        /** Unknown or malformed saved values remain unresolved rather than selecting a default. */
        fun fromSavedKey(key: String?): PublicRegistrationIntent? =
            entries.firstOrNull { it.savedKey == key }
    }
}
