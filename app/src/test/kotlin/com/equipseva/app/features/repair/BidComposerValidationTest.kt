package com.equipseva.app.features.repair

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BidComposerValidationTest {

    // ---- bidComposerAmountValid --------------------------------------

    @Test fun `positive amount valid`() {
        assertTrue(bidComposerAmountValid("2500"))
        assertTrue(bidComposerAmountValid("0.50"))
        assertTrue(bidComposerAmountValid("999999"))
    }

    @Test fun `zero amount invalid (server CHECK enforces positive)`() {
        // Critical pin — strict > 0.0. Server rejects 0 with
        // amount_must_be_positive.
        assertFalse(bidComposerAmountValid("0"))
        assertFalse(bidComposerAmountValid("0.0"))
    }

    @Test fun `negative amount invalid`() {
        assertFalse(bidComposerAmountValid("-500"))
    }

    @Test fun `blank amount invalid`() {
        assertFalse(bidComposerAmountValid(""))
        assertFalse(bidComposerAmountValid("   "))
    }

    @Test fun `non-numeric amount invalid`() {
        assertFalse(bidComposerAmountValid("abc"))
        assertFalse(bidComposerAmountValid("₹500"))
    }

    // ---- bidComposerEtaValid -----------------------------------------

    @Test fun `blank eta valid (eta is optional)`() {
        // Critical pin — blank is valid because etaHours is nullable
        // on the wire schema. A refactor that required a value would
        // break bids without ETAs.
        assertTrue(bidComposerEtaValid(""))
        assertTrue(bidComposerEtaValid("   "))
    }

    @Test fun `positive eta valid`() {
        assertTrue(bidComposerEtaValid("4"))
        assertTrue(bidComposerEtaValid("48"))
        assertTrue(bidComposerEtaValid("720"))
    }

    @Test fun `zero eta invalid (meaningless ETA)`() {
        // Pin strict > 0 — 0-hour ETA is meaningless.
        assertFalse(bidComposerEtaValid("0"))
    }

    @Test fun `negative eta invalid`() {
        assertFalse(bidComposerEtaValid("-1"))
    }

    @Test fun `non-integer eta invalid (would parse to null Int)`() {
        // toIntOrNull doesn't accept decimals.
        assertFalse(bidComposerEtaValid("4.5"))
        assertFalse(bidComposerEtaValid("abc"))
    }

    @Test fun `whitespace-padded eta is trimmed before parse`() {
        assertTrue(bidComposerEtaValid("  4  "))
    }
}
