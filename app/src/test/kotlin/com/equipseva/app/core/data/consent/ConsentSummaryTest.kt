package com.equipseva.app.core.data.consent

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1402 DPDP consent-centre helpers. */
class ConsentSummaryTest {

    private fun row(type: String, action: String = "granted") =
        ConsentRepository.ConsentRow(consentType = type, documentVersion = "v1", action = action, grantedAt = "2026-07-01T00:00:00Z")

    @Test fun `known consent types map to labels`() {
        assertEquals("Terms of Service", consentTypeLabel("terms_of_service"))
        assertEquals("Data processing (DPDP)", consentTypeLabel("dpdp_data_processing"))
        assertEquals("AMC auto-charge", consentTypeLabel("amc_auto_charge"))
    }

    @Test fun `unknown consent type de-snakes and capitalises`() {
        assertEquals("Biometric scan", consentTypeLabel("biometric_scan"))
    }

    @Test fun `categories map correctly`() {
        assertEquals("legal", consentCategory("privacy_policy"))
        assertEquals("marketing", consentCategory("whatsapp_business"))
        assertEquals("permissions", consentCategory("location_tracking"))
        assertEquals("billing", consentCategory("amc_auto_charge"))
        assertEquals("cookies", consentCategory("cookies_analytics"))
        assertEquals("other", consentCategory("something_new"))
    }

    @Test fun `groupConsents orders sections legal-first and sorts rows by label`() {
        val rows = listOf(
            row("marketing_sms"),
            row("amc_auto_charge"),
            row("privacy_policy"),
            row("location_tracking"),
            row("terms_of_service"),
        )
        val groups = groupConsents(rows)
        // legal, permissions, billing, marketing (order per CATEGORY_ORDER)
        assertEquals(listOf("Legal", "Device permissions", "Billing", "Marketing"), groups.map { it.categoryLabel })
        // legal group rows sorted by label: Privacy Policy before Terms of Service
        assertEquals(
            listOf("privacy_policy", "terms_of_service"),
            groups.first { it.categoryLabel == "Legal" }.rows.map { it.consentType },
        )
    }

    @Test fun `empty rows produce no groups`() {
        assertEquals(0, groupConsents(emptyList()).size)
    }

    @Test fun `only marketing analytics comms consents are withdrawable`() {
        assertEquals(true, isWithdrawableConsent("marketing_push"))
        assertEquals(true, isWithdrawableConsent("cookies_analytics"))
        assertEquals(true, isWithdrawableConsent("whatsapp_business"))
        assertEquals(false, isWithdrawableConsent("terms_of_service"))
        assertEquals(false, isWithdrawableConsent("amc_auto_charge"))
        assertEquals(false, isWithdrawableConsent("location_tracking"))
    }
}
