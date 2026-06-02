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
    /** Indian state (e.g. "Telangana"). Mandatory at hospital onboarding (v0.2.0). */
    val state: String? = null,
    /** District within state (e.g. "Hyderabad"). Mandatory at hospital onboarding (v0.2.0). */
    val district: String? = null,
    /**
     * Round 425 gate. Engineers must have BOTH a UPI and a bank
     * payout method on file before the app lets them past onboarding;
     * without this, the auto-payout queue accrues NULL-method rows
     * we can't drain and engineers go un-paid after release.
     *
     * Computed server-side via `engineer_has_complete_payout_methods()`
     * and attached during profile fetch. Null = not loaded yet
     * (treated as "not blocked" so cold-start doesn't flap into the
     * onboarding screen before the RPC resolves); always true for
     * non-engineers.
     */
    val hasEngineerPayoutComplete: Boolean? = null,
) {

    /**
     * True when the v0.2.0 onboarding gate is satisfied: phone + state +
     * district set for everyone, AND for engineers, also has both a UPI
     * and a bank payout method on file.
     */
    val hasCompletedV2Onboarding: Boolean
        get() {
            val baseDone = !phone.isNullOrBlank() && !state.isNullOrBlank() && !district.isNullOrBlank()
            if (!baseDone) return false
            // Engineer-only payout-method gate. Treat null (not yet
            // fetched) as "complete" so cold-start doesn't briefly
            // route engineers to onboarding before the RPC settles —
            // a follow-up fetch will reconcile.
            val activeKey = (activeRole ?: role)
            if (activeKey != UserRole.ENGINEER) return true
            return hasEngineerPayoutComplete != false
        }
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
        state = state,
        district = district,
    )
}
