package com.equipseva.app.features.dispute

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1445 dispute-evidence-pack helpers. */
class DisputePackHelpersTest {

    @Test fun `position statement needs at least 20 trimmed chars`() {
        assertEquals(false, isValidPositionStatement("too short"))
        assertEquals(false, isValidPositionStatement("   nineteen chars.  "))
        assertEquals(true, isValidPositionStatement("The engineer completed the job to spec on time."))
        assertEquals(true, isValidPositionStatement("x".repeat(20)))
        assertEquals(false, isValidPositionStatement("x".repeat(19)))
    }

    @Test fun `evidence kind de-snakes and falls back`() {
        assertEquals("Photo before", evidenceKindLabel("photo_before"))
        assertEquals("Dsr pdf", evidenceKindLabel("dsr_pdf"))
        assertEquals("Evidence", evidenceKindLabel(""))
    }
}
