package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the [KycStep] navigation + display contract. The KYC stepper
 * header reads `step.title` / `step.subtitle` directly and the
 * "Continue" CTA's enabled state is gated by `step.isLast`. A
 * regression that swapped `isFirst` / `isLast` would either silently
 * skip the validation gate or trap the user on the last step.
 */
class KycStepTest {

    @Test fun `Personal is step 1 with the pinned copy`() {
        val s = KycStep.Personal
        assertEquals(1, s.number)
        assertEquals("Personal", s.title)
        assertEquals("Name, email, phone, service area", s.subtitle)
        assertTrue(s.isFirst)
        assertFalse(s.isLast)
    }

    @Test fun `Documents is step 2 with the pinned copy`() {
        val s = KycStep.Documents
        assertEquals(2, s.number)
        assertEquals("Documents", s.title)
        assertEquals("Aadhaar + PAN + certificate", s.subtitle)
        assertFalse(s.isFirst)
        assertTrue(s.isLast)
    }

    @Test fun `next() advances from Personal to Documents`() {
        assertEquals(KycStep.Documents, KycStep.Personal.next())
    }

    @Test fun `next() returns null past the last step (no out-of-bounds)`() {
        assertNull(KycStep.Documents.next())
    }

    @Test fun `previous() returns null before the first step`() {
        assertNull(KycStep.Personal.previous())
    }

    @Test fun `previous() walks back from Documents to Personal`() {
        assertEquals(KycStep.Personal, KycStep.Documents.previous())
    }

    @Test fun `total is the count of entries`() {
        assertEquals(2, KycStep.total)
        assertEquals(KycStep.entries.size, KycStep.total)
    }
}
