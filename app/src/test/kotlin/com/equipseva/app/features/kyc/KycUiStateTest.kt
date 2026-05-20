package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Step-1 / Step-2 "can the user advance?" gate runs through
 * [KycViewModel.UiState.stepError], so it's the single point of truth for
 * what blocks Submit. Backfills the unit coverage that was dropped when
 * the AuthRepository / EngineerRepository signatures rotated (PR #255
 * note: "Stale KycViewModelTest... new tests in a follow-up").
 *
 * This test set covers only the pure derivation: stepError + canAdvance +
 * kycSubmitted. ViewModel-level wiring (load / save / Sentry breadcrumbs)
 * still lives in instrumented tests.
 */
class KycUiStateTest {

    private fun baseStep1() = KycViewModel.UiState(
        loading = false,
        currentStep = KycStep.Personal,
        fullName = "Ganesh Dhanavath",
        email = "ganesh@example.com",
        emailVerified = true,
        phone = "+919876543210",
        phoneVerified = true,
        serviceState = "Karnataka",
        serviceDistrict = "Bangalore Urban",
    )

    private fun baseStep2() = KycViewModel.UiState(
        loading = false,
        currentStep = KycStep.Documents,
        aadhaarNumber = "234123412346",
        panNumber = "ABCDE1234F",
        aadhaarDocPath = "aadhaar/x.jpg",
        panDocPath = "pan/x.jpg",
        certDocPaths = listOf("cert/c1.pdf"),
        attestationAccepted = true,
    )

    @Test fun `verified status short-circuits stepError to null on every step`() {
        val s1 = baseStep1().copy(
            verificationStatus = VerificationStatus.Verified,
            fullName = null, // would normally block
            serviceState = null,
        )
        val s2 = baseStep2().copy(
            verificationStatus = VerificationStatus.Verified,
            aadhaarDocPath = null, // would normally block
        )
        assertNull(s1.stepError())
        assertNull(s2.stepError())
    }

    @Test fun `Personal step requires a non-blank full name`() {
        val state = baseStep1().copy(fullName = "   ")
        assertEquals(
            "Add your name from Profile settings before continuing.",
            state.stepError(),
        )
    }

    @Test fun `Personal step requires a present email`() {
        val state = baseStep1().copy(email = null)
        assertEquals(
            "Email missing — add it before continuing.",
            state.stepError(),
        )
    }

    @Test fun `Personal step rejects an obviously-bad email`() {
        val state = baseStep1().copy(email = "no-at-sign", emailVerified = false)
        assertEquals(
            "That email doesn't look right.",
            state.stepError(),
        )
    }

    @Test fun `Personal step blocks until the email is verified`() {
        val state = baseStep1().copy(emailVerified = false)
        assertEquals(
            "Verify your email — tap the Verify button.",
            state.stepError(),
        )
    }

    @Test fun `Personal step requires a picked state and district`() {
        val noState = baseStep1().copy(serviceState = null)
        assertEquals("Pick the state you serve.", noState.stepError())

        val noDistrict = baseStep1().copy(serviceDistrict = "  ")
        assertEquals("Pick the district you serve.", noDistrict.stepError())
    }

    @Test fun `Personal step ignores missing phone`() {
        // Phone CTA was demoted from a hard gate in PR #211 — pin that
        // contract so it doesn't quietly re-tighten.
        val state = baseStep1().copy(phone = null, phoneVerified = false)
        assertNull(state.stepError())
    }

    @Test fun `Documents step requires a 12-digit Aadhaar`() {
        val state = baseStep2().copy(aadhaarNumber = "123")
        assertEquals("Aadhaar must be 12 digits.", state.stepError())
    }

    @Test fun `Documents step blocks on a length-correct but invalid Aadhaar`() {
        val state = baseStep2().copy(aadhaarNumber = "234123412345")
        assertEquals(
            "That doesn't look like a valid Aadhaar number.",
            state.stepError(),
        )
    }

    @Test fun `Documents step requires the Aadhaar doc upload`() {
        val state = baseStep2().copy(aadhaarDocPath = null)
        assertEquals(
            "Upload your Aadhaar (PDF or photo) before continuing.",
            state.stepError(),
        )
    }

    @Test fun `Documents step requires a 10-char PAN`() {
        val state = baseStep2().copy(panNumber = "ABCDE")
        assertEquals(
            "PAN must be 10 characters (5 letters, 4 digits, 1 letter).",
            state.stepError(),
        )
    }

    @Test fun `Documents step blocks on length-correct but invalid PAN`() {
        val state = baseStep2().copy(panNumber = "ABCDE12345")
        assertEquals(
            "That doesn't look like a valid PAN.",
            state.stepError(),
        )
    }

    @Test fun `Documents step requires the PAN doc upload`() {
        val state = baseStep2().copy(panDocPath = "  ")
        assertEquals(
            "Upload a photo of your PAN card.",
            state.stepError(),
        )
    }

    @Test fun `Documents step requires at least one certificate`() {
        val state = baseStep2().copy(certDocPaths = emptyList())
        assertEquals(
            "Upload at least one trade or qualification certificate.",
            state.stepError(),
        )
    }

    @Test fun `Documents step requires attestation`() {
        val state = baseStep2().copy(attestationAccepted = false)
        assertEquals(
            "You must confirm the attestation to submit.",
            state.stepError(),
        )
    }

    @Test fun `kycSubmitted is true only with all three doc slots filled`() {
        assertTrue(baseStep2().kycSubmitted)
        assertFalse(baseStep2().copy(aadhaarDocPath = null).kycSubmitted)
        assertFalse(baseStep2().copy(panDocPath = "  ").kycSubmitted)
        assertFalse(baseStep2().copy(certDocPaths = emptyList()).kycSubmitted)
    }

    @Test fun `canAdvance gates on stepError and not on background uploads`() {
        val good = baseStep2()
        assertTrue(good.canAdvance)

        // A live upload blocks Advance even with no field-level error.
        val uploading = good.copy(uploadingAadhaar = true)
        assertFalse(uploading.canAdvance)
        val uploadingCert = good.copy(uploadingCert = true)
        assertFalse(uploadingCert.canAdvance)
        val uploadingPan = good.copy(uploadingPan = true)
        assertFalse(uploadingPan.canAdvance)
    }
}
