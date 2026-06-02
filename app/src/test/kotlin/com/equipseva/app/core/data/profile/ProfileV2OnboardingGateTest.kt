package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProfileV2OnboardingGateTest {

    private fun base(
        role: UserRole? = UserRole.ENGINEER,
        phone: String? = "+919999999999",
        state: String? = "Telangana",
        district: String? = "Hyderabad",
        payoutComplete: Boolean? = null,
    ): Profile = Profile(
        id = "u1",
        email = "e@x.com",
        phone = phone,
        fullName = "Engineer One",
        avatarUrl = null,
        role = role,
        rawRoleKey = role?.storageKey,
        roleConfirmed = true,
        onboardingCompleted = true,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
        state = state,
        district = district,
        hasEngineerPayoutComplete = payoutComplete,
    )

    @Test
    fun `engineer with payout complete passes gate`() {
        assertTrue(base(payoutComplete = true).hasCompletedV2Onboarding)
    }

    @Test
    fun `engineer with payout incomplete is gated`() {
        assertFalse(base(payoutComplete = false).hasCompletedV2Onboarding)
    }

    @Test
    fun `engineer with payout null is NOT gated to avoid cold-start flap`() {
        // Null = payout RPC not loaded yet; treat as passing so the
        // first paint after sign-in doesn't briefly mount the payout
        // onboarding screen for engineers whose methods are about to
        // load. A follow-up fetch will reconcile.
        assertTrue(base(payoutComplete = null).hasCompletedV2Onboarding)
    }

    @Test
    fun `engineer missing phone fails even when payout complete`() {
        assertFalse(base(phone = null, payoutComplete = true).hasCompletedV2Onboarding)
    }

    @Test
    fun `hospital with payout null still passes (gate is engineer-only)`() {
        assertTrue(base(role = UserRole.HOSPITAL, payoutComplete = null).hasCompletedV2Onboarding)
    }

    @Test
    fun `hospital missing district fails regardless of payout flag`() {
        assertFalse(base(role = UserRole.HOSPITAL, district = null, payoutComplete = true).hasCompletedV2Onboarding)
    }
}
