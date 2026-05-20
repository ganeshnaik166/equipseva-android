package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The KYC wizard is two-step (Personal → Documents) after v2 dropped the
 * Selfie step. The stepper uses [KycStep.next] / [KycStep.previous] to
 * advance / retreat, and the progress chip reads off [KycStep.number] /
 * [KycStep.total]. A silent re-order (e.g. inserting a third step in the
 * wrong place) would either hide the Submit CTA or break the progress
 * indicator — pin the contract here.
 */
class KycStepTest {

    @Test fun `step ordering matches the wizard contract`() {
        assertEquals(0, KycStep.Personal.ordinal)
        assertEquals(1, KycStep.Documents.ordinal)
        assertEquals(1, KycStep.Personal.number)
        assertEquals(2, KycStep.Documents.number)
    }

    @Test fun `next walks Personal to Documents and stops`() {
        assertEquals(KycStep.Documents, KycStep.Personal.next())
        assertNull(KycStep.Documents.next())
    }

    @Test fun `previous walks Documents to Personal and stops`() {
        assertEquals(KycStep.Personal, KycStep.Documents.previous())
        assertNull(KycStep.Personal.previous())
    }

    @Test fun `isFirst and isLast bracket the wizard correctly`() {
        assertTrue(KycStep.Personal.isFirst)
        assertFalse(KycStep.Personal.isLast)

        assertFalse(KycStep.Documents.isFirst)
        assertTrue(KycStep.Documents.isLast)
    }

    @Test fun `total reflects the current entries`() {
        // The stepper UI reads "Step N of {total}" — if a new step is added
        // (or removed) the number on the chip must move with it.
        assertEquals(KycStep.entries.size, KycStep.total)
        // Sanity-check the post-selfie-drop contract specifically.
        assertEquals(2, KycStep.total)
    }
}
