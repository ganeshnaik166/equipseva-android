package com.equipseva.app.navigation

import com.equipseva.app.features.auth.SessionState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Synthetic route decisions; no account, device or network is used. */
class AuthHandoffPolicyTest {
    @Test fun `hospital signup cannot skip mandatory phone when profile validates first`() {
        assertEquals(null, authHandoffDestination(ready("hospital_admin"), Routes.AUTH_SIGN_UP, false))
        assertEquals(null, authHandoffDestination(onboarding("hospital_admin"), Routes.AUTH_SIGN_UP, false))
        assertEquals(null, authHandoffDestination(ready("hospital_admin"), Routes.HOSPITAL_PHONE_ONBOARDING, false))
        assertEquals(AuthHandoffDestination.MAIN,
            authHandoffDestination(ready("hospital_admin"), Routes.HOSPITAL_PHONE_ONBOARDING, true))
        assertEquals(AuthHandoffDestination.ONBOARDING,
            authHandoffDestination(onboarding("hospital_admin"), Routes.HOSPITAL_PHONE_ONBOARDING, true))
    }

    @Test fun `only server confirmed hospital can enter phone after signup effect`() {
        assertFalse(mayEnterHospitalPhone(SessionState.NeedsRole("A", "a@test.invalid")))
        assertFalse(mayEnterHospitalPhone(ready("engineer")))
        assertTrue(mayEnterHospitalPhone(ready("hospital_admin")))
        assertTrue(mayEnterHospitalPhone(onboarding("hospital_admin")))
    }

    @Test fun `engineer signup and ordinary sign in hand off by verified profile`() {
        assertEquals(AuthHandoffDestination.MAIN,
            authHandoffDestination(ready("engineer"), Routes.AUTH_SIGN_UP, false))
        assertEquals(AuthHandoffDestination.ONBOARDING,
            authHandoffDestination(onboarding("engineer"), Routes.AUTH_SIGN_UP, false))
        assertEquals(AuthHandoffDestination.ONBOARDING,
            authHandoffDestination(onboarding("hospital_admin"), Routes.AUTH_SIGN_IN, false))
        assertEquals(null,
            authHandoffDestination(SessionState.NeedsRole("A", "a@test.invalid"), Routes.AUTH_SIGN_IN, false))
        assertEquals(null,
            authHandoffDestination(ready("supplier"), Routes.AUTH_SIGN_IN, false))
    }

    private fun ready(role: String) = SessionState.Ready("A", "a@test.invalid", role)
    private fun onboarding(role: String) = SessionState.NeedsOnboarding("A", "a@test.invalid", role)
}
