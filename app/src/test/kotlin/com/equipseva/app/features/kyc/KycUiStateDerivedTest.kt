package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the derived gates on [KycViewModel.UiState]:
 *
 *   * `stepError()` — returns the one-line, user-safe message for the
 *     current step's first unmet requirement, or null if the step is
 *     complete. The order of checks matters: when the engineer has
 *     entered junk on multiple fields, we show the first one so they
 *     can fix it without seeing a wall of errors.
 *   * `canAdvance` — composes `stepError() == null` with no-uploads-
 *     in-flight. A regression that dropped the upload-in-flight guard
 *     would let users advance while a doc is still uploading, leading
 *     to the next step seeing a stale doc path.
 *   * `kycSubmitted` — three required docs present. Drives the
 *     timeline + status-banner copy. The previous `aadhaarVerified`
 *     proxy claimed "submitted" too eagerly; pin the three-doc gate.
 *
 * Verified engineers skip step validation entirely (they're just
 * viewing their submission), so stepError() returns null on every step
 * regardless of field state.
 */
class KycUiStateDerivedTest {

    private val basePersonalGood = KycViewModel.UiState(
        loading = false,
        verificationStatus = VerificationStatus.Pending,
        fullName = "Ravi Kumar",
        email = "ravi@x.in",
        emailVerified = true,
        serviceState = "Telangana",
        serviceDistrict = "Hyderabad",
        currentStep = KycStep.Personal,
    )

    private val baseDocumentsGood = basePersonalGood.copy(
        currentStep = KycStep.Documents,
        aadhaarNumber = "234123412346",
        aadhaarDocPath = "k/aadhaar.jpg",
        panNumber = "ABCDE1234F",
        panDocPath = "k/pan.jpg",
        certDocPaths = listOf("k/cert.jpg"),
        attestationAccepted = true,
    )

    // ---- stepError on Personal step ----

    @Test fun `Personal step error when fullName is null`() {
        val state = basePersonalGood.copy(fullName = null)
        assertEquals(
            "Add your name from Profile settings before continuing.",
            state.stepError(),
        )
    }

    @Test fun `Personal step error when fullName is blank`() {
        val state = basePersonalGood.copy(fullName = "  ")
        assertEquals(
            "Add your name from Profile settings before continuing.",
            state.stepError(),
        )
    }

    @Test fun `Personal step error when email is missing`() {
        val state = basePersonalGood.copy(email = null)
        assertEquals("Email missing — add it before continuing.", state.stepError())
    }

    @Test fun `Personal step error when email is invalid`() {
        val state = basePersonalGood.copy(email = "not-an-email")
        assertEquals("That email doesn't look right.", state.stepError())
    }

    @Test fun `Personal step error when email is unverified`() {
        val state = basePersonalGood.copy(emailVerified = false)
        assertEquals("Verify your email — tap the Verify button.", state.stepError())
    }

    @Test fun `Personal step error when serviceState is null`() {
        val state = basePersonalGood.copy(serviceState = null)
        assertEquals("Pick the state you serve.", state.stepError())
    }

    @Test fun `Personal step error when serviceDistrict is null`() {
        val state = basePersonalGood.copy(serviceDistrict = null)
        assertEquals("Pick the district you serve.", state.stepError())
    }

    @Test fun `Personal step error null when all fields are good`() {
        assertNull(basePersonalGood.stepError())
    }

    @Test fun `Personal step skips phone-missing — phone no longer hard-gates KYC`() {
        // Personal step explicitly does NOT gate on phone — engineers
        // can submit without a phone and add it later from Profile.
        // Pin so a future tightening surfaces in review.
        val state = basePersonalGood.copy(phone = null)
        assertNull(state.stepError())
    }

    // ---- stepError on Documents step ----

    @Test fun `Documents step error when Aadhaar is not 12 digits`() {
        val state = baseDocumentsGood.copy(aadhaarNumber = "12345")
        assertEquals("Aadhaar must be 12 digits.", state.stepError())
    }

    @Test fun `Documents step error when Aadhaar fails Verhoeff check`() {
        val state = baseDocumentsGood.copy(aadhaarNumber = "123456789012")
        assertEquals("That doesn't look like a valid Aadhaar number.", state.stepError())
    }

    @Test fun `Documents step error when Aadhaar doc not uploaded`() {
        val state = baseDocumentsGood.copy(aadhaarDocPath = null)
        assertEquals("Upload your Aadhaar (PDF or photo) before continuing.", state.stepError())
    }

    @Test fun `Documents step error when PAN is wrong length`() {
        val state = baseDocumentsGood.copy(panNumber = "AB123")
        assertEquals(
            "PAN must be 10 characters (5 letters, 4 digits, 1 letter).",
            state.stepError(),
        )
    }

    @Test fun `Documents step error when PAN fails pattern`() {
        val state = baseDocumentsGood.copy(panNumber = "1234567890")
        assertEquals("That doesn't look like a valid PAN.", state.stepError())
    }

    @Test fun `Documents step error when PAN doc not uploaded`() {
        val state = baseDocumentsGood.copy(panDocPath = null)
        assertEquals("Upload a photo of your PAN card.", state.stepError())
    }

    @Test fun `Documents step error when no certs uploaded`() {
        val state = baseDocumentsGood.copy(certDocPaths = emptyList())
        assertEquals("Upload at least one trade or qualification certificate.", state.stepError())
    }

    @Test fun `Documents step error when attestation not accepted`() {
        val state = baseDocumentsGood.copy(attestationAccepted = false)
        assertEquals("You must confirm the attestation to submit.", state.stepError())
    }

    @Test fun `Documents step error null when all fields are good`() {
        assertNull(baseDocumentsGood.stepError())
    }

    // ---- Verified engineers bypass validation ----

    @Test fun `Verified status short-circuits stepError to null even with empty fields`() {
        val state = KycViewModel.UiState(
            loading = false,
            verificationStatus = VerificationStatus.Verified,
            currentStep = KycStep.Documents,
            // All fields intentionally blank.
        )
        assertNull(state.stepError())
    }

    // ---- canAdvance ----

    @Test fun `canAdvance true on the happy path`() {
        assertTrue(basePersonalGood.canAdvance)
        assertTrue(baseDocumentsGood.canAdvance)
    }

    @Test fun `canAdvance false when any upload is in flight`() {
        assertFalse(basePersonalGood.copy(uploadingAadhaar = true).canAdvance)
        assertFalse(basePersonalGood.copy(uploadingPan = true).canAdvance)
        assertFalse(basePersonalGood.copy(uploadingCert = true).canAdvance)
    }

    @Test fun `canAdvance false when stepError is non-null even with no uploads`() {
        assertFalse(basePersonalGood.copy(fullName = null).canAdvance)
    }

    // ---- kycSubmitted ----

    @Test fun `kycSubmitted true when all three docs are present`() {
        val state = KycViewModel.UiState(
            aadhaarDocPath = "k/aadhaar.jpg",
            panDocPath = "k/pan.jpg",
            certDocPaths = listOf("k/cert.jpg"),
        )
        assertTrue(state.kycSubmitted)
    }

    @Test fun `kycSubmitted false when aadhaar doc is missing`() {
        val state = KycViewModel.UiState(
            aadhaarDocPath = null,
            panDocPath = "k/pan.jpg",
            certDocPaths = listOf("k/cert.jpg"),
        )
        assertFalse(state.kycSubmitted)
    }

    @Test fun `kycSubmitted false when pan doc is missing`() {
        val state = KycViewModel.UiState(
            aadhaarDocPath = "k/aadhaar.jpg",
            panDocPath = null,
            certDocPaths = listOf("k/cert.jpg"),
        )
        assertFalse(state.kycSubmitted)
    }

    @Test fun `kycSubmitted false when no cert is uploaded`() {
        val state = KycViewModel.UiState(
            aadhaarDocPath = "k/aadhaar.jpg",
            panDocPath = "k/pan.jpg",
            certDocPaths = emptyList(),
        )
        assertFalse(state.kycSubmitted)
    }

    @Test fun `kycSubmitted false when aadhaar doc path is blank string`() {
        // Defensive — historical KYC writes pushed empty strings,
        // mapper folds those to null but the UiState may carry them
        // transiently. Pin the blank-not-null guard.
        val state = KycViewModel.UiState(
            aadhaarDocPath = "  ",
            panDocPath = "k/pan.jpg",
            certDocPaths = listOf("k/cert.jpg"),
        )
        assertFalse(state.kycSubmitted)
    }
}
