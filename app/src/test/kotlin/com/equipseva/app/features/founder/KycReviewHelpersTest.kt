package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

class KycReviewHelpersTest {

    // ---- kycReviewAvatarInitial --------------------------------------

    @Test fun `non-empty name's first letter uppercased`() {
        assertEquals("A", kycReviewAvatarInitial("asha rao"))
    }

    @Test fun `already-uppercase first letter stays uppercase`() {
        assertEquals("Z", kycReviewAvatarInitial("Zara"))
    }

    @Test fun `empty name falls back to E (engineer-specific, not question mark)`() {
        // Critical pin — "E" not "?". The KYC review screen is
        // always reviewing an engineer, so "E" is more informative
        // than the generic "?" used on the Users row.
        assertEquals("E", kycReviewAvatarInitial(""))
    }

    @Test fun `digit first-char stays as digit (uppercase no-op)`() {
        assertEquals("9", kycReviewAvatarInitial("9to5"))
    }

    // ---- experienceYearsLabel ----------------------------------------

    @Test fun `1 year reads singular`() {
        // Critical pin — never "1 years".
        assertEquals("1 year", experienceYearsLabel(1))
    }

    @Test fun `2 years reads plural`() {
        assertEquals("2 years", experienceYearsLabel(2))
    }

    @Test fun `0 years reads plural (no 0-year special case)`() {
        // Pin defensively — wire shouldn't allow 0 but the helper
        // stays total.
        assertEquals("0 years", experienceYearsLabel(0))
    }

    @Test fun `large years interpolates with plural`() {
        assertEquals("42 years", experienceYearsLabel(42))
    }

    @Test fun `negative years interpolates with plural (defensive)`() {
        // Pin — exact `== 1` gate doesn't match negative; falls
        // through to plural. A refactor to `<= 1` would surface
        // "-3 year".
        assertEquals("-3 years", experienceYearsLabel(-3))
    }
}
