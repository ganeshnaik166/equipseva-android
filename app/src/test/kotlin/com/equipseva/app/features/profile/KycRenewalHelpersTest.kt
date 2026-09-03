package com.equipseva.app.features.profile

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [KycRenewalScreen] (round3779) — the
 * first Android client of the round497 engineer periodic re-KYC
 * backend.
 */
class KycRenewalHelpersTest {

    @Test fun `known items map to readable labels`() {
        assertEquals("Aadhaar", kycRenewalItemLabel("aadhaar"))
        assertEquals("Degree (DigiLocker)", kycRenewalItemLabel("degree_digilocker"))
        assertEquals("Police verification", kycRenewalItemLabel("police_verification"))
        assertEquals("Profile photo", kycRenewalItemLabel("photo"))
    }

    @Test fun `unknown item falls back to humanised raw string`() {
        assertEquals("Some future item", kycRenewalItemLabel("some_future_item"))
    }

    @Test fun `overdue renewal phrases as overdue, floor 1 day`() {
        assertEquals("Renewal overdue by 1 day", kycRenewalDueInText(-0.3))
        assertEquals("Renewal overdue by 5 days", kycRenewalDueInText(-5.0))
    }

    @Test fun `due today and due in N days phrase correctly`() {
        assertEquals("Renewal due today", kycRenewalDueInText(0.4))
        assertEquals("Renewal due in 1 day", kycRenewalDueInText(1.0))
        assertEquals("Renewal due in 12 days", kycRenewalDueInText(12.3))
    }
}
