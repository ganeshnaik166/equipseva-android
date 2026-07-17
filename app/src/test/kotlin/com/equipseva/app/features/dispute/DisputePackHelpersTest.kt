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

    // r1501 — the file gate mirrors the server's
    // pack_must_have_evidence_or_dsr_before_submit guard, blocking ONLY on
    // positive knowledge that both evidence and DSR are absent.

    @Test fun `needs evidence when none selected and job positively has no DSR`() {
        assertEquals(true, disputePackNeedsEvidence(selectedEvidenceCount = 0, hasDsr = false))
    }

    @Test fun `selecting any evidence clears the gate`() {
        assertEquals(false, disputePackNeedsEvidence(selectedEvidenceCount = 1, hasDsr = false))
    }

    @Test fun `a linked DSR clears the gate even with zero evidence`() {
        assertEquals(false, disputePackNeedsEvidence(selectedEvidenceCount = 0, hasDsr = true))
    }

    @Test fun `unknown DSR state never blocks (server backstops)`() {
        // null = still loading or the lookup failed — blocking here would
        // wrongly lock out a filer whose job HAS a DSR.
        assertEquals(false, disputePackNeedsEvidence(selectedEvidenceCount = 0, hasDsr = null))
    }
}
