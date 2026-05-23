package com.equipseva.app.features.onboarding

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the onboarding-tour CTA label. The "Next" → "Get started"
 * transition is the activation signal — pin so a refactor that
 * lost the boundary doesn't break the user's expectation that the
 * tour culminates in an action.
 */
class TourCtaLabelTest {

    @Test fun `step 0 of 3 reads Next`() {
        assertEquals("Next", tourCtaLabel(step = 0, totalPages = 3))
    }

    @Test fun `step 1 of 3 reads Next`() {
        assertEquals("Next", tourCtaLabel(step = 1, totalPages = 3))
    }

    @Test fun `step 2 of 3 (last page) reads Get started`() {
        // Critical pin — the activation signal.
        assertEquals("Get started", tourCtaLabel(step = 2, totalPages = 3))
    }

    @Test fun `single-page tour reads Get started immediately`() {
        // Boundary — step 0 is the last page when totalPages == 1.
        assertEquals("Get started", tourCtaLabel(step = 0, totalPages = 1))
    }

    @Test fun `Get started phrasing is preserved verbatim`() {
        // Pin literal — "Done" or "Continue" would lose the activation
        // semantics. "Get started" implies preamble→action transition.
        val out = tourCtaLabel(step = 2, totalPages = 3)
        assertEquals("Get started", out)
    }

    @Test fun `Next phrasing is preserved verbatim`() {
        // Pin literal — "Continue" or "→" would lose the explicit
        // forward-step phrasing.
        val out = tourCtaLabel(step = 0, totalPages = 3)
        assertEquals("Next", out)
    }

    @Test fun `out-of-range step (beyond last page) still reads Get started`() {
        // Defensive — caller caps step at lastIndex, but pin the
        // total-function shape.
        assertEquals("Get started", tourCtaLabel(step = 99, totalPages = 3))
    }
}
