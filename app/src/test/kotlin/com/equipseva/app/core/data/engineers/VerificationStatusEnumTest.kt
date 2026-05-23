package com.equipseva.app.core.data.engineers

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the [VerificationStatus] wire-string contract + the
 * fromKey-null-or-unknown → Pending fallback. The storage keys mirror
 * Postgres `verification_status` enum values exactly; the display
 * copy ships into the founder KYC queue + the engineer Profile
 * verification chip.
 *
 * The Pending fallback is the easy regression — a client that
 * shipped before a new server-side status surfaces it as Pending
 * (closest to "unknown, treat conservatively") rather than crashing.
 */
class VerificationStatusEnumTest {

    @Test fun `keys match the pinned wire strings`() {
        assertEquals("pending", VerificationStatus.Pending.storageKey)
        assertEquals("verified", VerificationStatus.Verified.storageKey)
        assertEquals("rejected", VerificationStatus.Rejected.storageKey)
    }

    @Test fun `display copy matches the pinned product strings`() {
        assertEquals("Pending review", VerificationStatus.Pending.displayName)
        assertEquals("Verified", VerificationStatus.Verified.displayName)
        assertEquals("Rejected", VerificationStatus.Rejected.displayName)
    }

    @Test fun `fromKey resolves known keys`() {
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey("pending"))
        assertEquals(VerificationStatus.Verified, VerificationStatus.fromKey("verified"))
        assertEquals(VerificationStatus.Rejected, VerificationStatus.fromKey("rejected"))
    }

    @Test fun `fromKey null falls back to Pending`() {
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey(null))
    }

    @Test fun `fromKey unknown key falls back to Pending (conservative default)`() {
        // Pending is the conservative bucket — a future server-side
        // status that the client doesn't recognise surfaces as
        // "pending review" rather than promoting to Verified.
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey("future_state"))
    }

    @Test fun `fromKey is strict on case (lowercase contract)`() {
        // Server emits lowercase; mixed-case shouldn't match — pin
        // so a "tolerant lowercase()" change is reviewed (would
        // hide real wire-format bugs).
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey("VERIFIED"))
    }

    @Test fun `three statuses total`() {
        assertEquals(3, VerificationStatus.entries.size)
    }
}
