package com.equipseva.app.testing

import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.features.auth.UserRole

/**
 * Profile fixtures for the UI-A01 auth/navigation audit tests. They model the
 * server states the session gate actually distinguishes:
 *
 *  - [confirmedProfile]: `role_confirmed = true`, `active_role` set — what the
 *    `add_role` RPC or a RoleSelect confirm produces.
 *  - [triggerDefaultProfile]: what `handle_new_user` + `_sync_profile_roles`
 *    leave behind for a brand-new auth user before any role RPC ran —
 *    scalar `role = 'engineer'` (hardcoded by the trigger), `roles =
 *    ['engineer']`, `active_role = 'engineer'`, `role_confirmed = false`.
 *    This is the state of every first-time Google sign-in and of any email
 *    sign-up whose `add_role` call failed.
 *  - [minimalFallbackProfile]: the cross-user-RPC fallback shape
 *    `SupabaseProfileRepository.fetchById` synthesises when both self
 *    selects fail but `public_profiles_minimal` still returns the row:
 *    no role, not confirmed, `isActive = true`, no phone.
 */
object AuthAuditFixtures {

    const val UID_A = "aaaaaaaa-0000-4000-8000-000000000001"
    const val UID_B = "bbbbbbbb-0000-4000-8000-000000000002"
    const val EMAIL_A = "a@test.invalid"
    const val EMAIL_B = "b@test.invalid"

    fun confirmedProfile(
        id: String = UID_A,
        email: String? = EMAIL_A,
        role: UserRole = UserRole.HOSPITAL,
        onboarded: Boolean = true,
        isActive: Boolean = true,
        payoutComplete: Boolean? = null,
    ): Profile = Profile(
        id = id,
        email = email,
        phone = if (onboarded) "+919999999999" else null,
        fullName = "User $id",
        avatarUrl = null,
        role = role,
        rawRoleKey = role.storageKey,
        roleConfirmed = true,
        onboardingCompleted = onboarded,
        isActive = isActive,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
        roles = listOf(role),
        rawRoleKeys = listOf(role.storageKey),
        activeRole = role,
        activeRoleKey = role.storageKey,
        state = if (onboarded) "Telangana" else null,
        district = if (onboarded) "Hyderabad" else null,
        hasEngineerPayoutComplete = payoutComplete,
    )

    fun triggerDefaultProfile(
        id: String = UID_A,
        email: String? = EMAIL_A,
    ): Profile = Profile(
        id = id,
        email = email,
        phone = null,
        fullName = "User $id",
        avatarUrl = null,
        role = UserRole.ENGINEER,
        rawRoleKey = UserRole.ENGINEER.storageKey,
        roleConfirmed = false,
        onboardingCompleted = false,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
        roles = listOf(UserRole.ENGINEER),
        rawRoleKeys = listOf(UserRole.ENGINEER.storageKey),
        activeRole = UserRole.ENGINEER,
        activeRoleKey = UserRole.ENGINEER.storageKey,
    )

    fun minimalFallbackProfile(id: String = UID_A): Profile = Profile(
        id = id,
        email = null,
        phone = null,
        fullName = "User $id",
        avatarUrl = null,
        role = null,
        rawRoleKey = null,
        roleConfirmed = false,
        onboardingCompleted = false,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
    )
}
