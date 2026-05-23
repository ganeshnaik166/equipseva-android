package com.equipseva.app.features.home

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanSubmitSpotAuditTest {

    @Test fun `rating 1 enables submit (lower inclusive boundary)`() {
        assertTrue(canSubmitSpotAudit(1, submitting = false))
    }

    @Test fun `rating 5 enables submit (upper inclusive boundary)`() {
        assertTrue(canSubmitSpotAudit(5, submitting = false))
    }

    @Test fun `rating 0 blocks (no rating picked yet)`() {
        // Critical pin — 0 means "no star tapped"; submit should
        // not fire on the default state.
        assertFalse(canSubmitSpotAudit(0, submitting = false))
    }

    @Test fun `rating 6 blocks (out of range)`() {
        // Server CHECK constraint matches 1..5 — pin to avoid mid-
        // action server-side rejection.
        assertFalse(canSubmitSpotAudit(6, submitting = false))
    }

    @Test fun `negative rating blocks (defensive)`() {
        assertFalse(canSubmitSpotAudit(-1, submitting = false))
    }

    @Test fun `submitting blocks regardless of valid rating`() {
        assertFalse(canSubmitSpotAudit(5, submitting = true))
    }

    @Test fun `rating 3 mid-range enables`() {
        assertTrue(canSubmitSpotAudit(3, submitting = false))
    }
}
