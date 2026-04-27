package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole

data class Profile(
    val id: String,
    val email: String?,
    val phone: String?,
    val fullName: String?,
    val avatarUrl: String?,
    val role: UserRole?,
    val rawRoleKey: String?,
    val roleConfirmed: Boolean,
    val onboardingCompleted: Boolean,
    val isActive: Boolean,
    val organizationId: String?,
    val organizationName: String?,
    val organizationCity: String?,
    val organizationState: String?,
    // S0b: multi-service support. Old scalar `role` stays for back-compat,
    // every screen still reads it. New Hub-aware code uses `roles` +
    // `activeRole`.
    val roles: List<UserRole> = emptyList(),
    val rawRoleKeys: List<String> = emptyList(),
    val activeRole: UserRole? = null,
    val activeRoleKey: String? = null,
    /** S1: buyer KYC gate. Values: unsubmitted | pending | verified | rejected. */
    val buyerKycStatus: String = "unsubmitted",
    /** True iff Supabase has confirmed the email (auth.users.email_confirmed_at). */
    val emailVerified: Boolean = false,
    /** True iff Supabase has confirmed the phone (auth.users.phone_confirmed_at). */
    val phoneVerified: Boolean = false,
) {
    val displayName: String
        get() = fullName?.takeIf { it.isNotBlank() }
            ?: email?.substringBefore('@')
            ?: "User"

    val locationLine: String?
        get() = listOfNotNull(organizationCity, organizationState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }

    /**
     * Email-pinned founder check. Pure-client heuristic for surfacing the
     * Founder dashboard tab — server-side enforcement still happens via
     * `is_founder()` SQL function (which checks `auth.email()`) on every
     * privileged RPC. So flipping this to true on a non-founder client only
     * shows them an empty dashboard with no actionable rows.
     */
    fun isFounder(): Boolean =
        email?.equals(FOUNDER_EMAIL, ignoreCase = true) == true

    companion object {
        const val FOUNDER_EMAIL = "ganesh1431.dhanavath@gmail.com"
    }
}

internal fun ProfileDto.toDomain(): Profile {
    val rawKeys = roles.orEmpty()
    val mappedRoles = rawKeys.mapNotNull { key -> UserRole.entries.firstOrNull { it.storageKey == key } }
    return Profile(
        id = id,
        email = email,
        phone = phone,
        fullName = fullName,
        avatarUrl = avatarUrl,
        role = role?.let { key -> UserRole.entries.firstOrNull { it.storageKey == key } },
        rawRoleKey = role,
        roleConfirmed = roleConfirmed,
        onboardingCompleted = onboardingCompleted,
        isActive = isActive,
        organizationId = organizationId,
        organizationName = organizations?.name,
        organizationCity = organizations?.city,
        organizationState = organizations?.state,
        roles = mappedRoles,
        rawRoleKeys = rawKeys,
        activeRole = activeRoleKey?.let { key -> UserRole.entries.firstOrNull { it.storageKey == key } },
        activeRoleKey = activeRoleKey,
        buyerKycStatus = buyerKycStatus ?: "unsubmitted",
        emailVerified = emailVerified,
        phoneVerified = phoneVerified,
    )
}
