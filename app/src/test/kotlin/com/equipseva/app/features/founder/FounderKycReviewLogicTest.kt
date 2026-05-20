package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the hero subtitle on the founder KYC review screen
 * ("Hyderabad · submitted 2025-04-12"). The composition pattern is
 * `listOfNotNull(...).joinToString(" · ")` so missing fields drop
 * out cleanly — the test pins each combination to lock the visual.
 */
class FounderKycReviewLogicTest {

    @Test fun `city and submitted date both present join with separator`() {
        assertEquals(
            "Hyderabad · submitted 2025-04-12",
            founderReviewSubtitle("Hyderabad", "2025-04-12T10:00:00Z"),
        )
    }

    @Test fun `city only drops the separator entirely`() {
        // No stray " · " when only one field is present.
        assertEquals("Hyderabad", founderReviewSubtitle("Hyderabad", null))
    }

    @Test fun `submitted date only drops the separator`() {
        assertEquals(
            "submitted 2025-04-12",
            founderReviewSubtitle(null, "2025-04-12T10:00:00Z"),
        )
    }

    @Test fun `both missing returns an empty string for the composable to hide`() {
        // Empty-string contract — the call-site checks `isNotBlank()`
        // before rendering, so a missing engineer profile collapses the
        // hero subtitle row entirely instead of taking vertical space.
        assertEquals("", founderReviewSubtitle(null, null))
    }

    @Test fun `submitted date is truncated to the first 10 chars`() {
        // Founder doesn't care about the time-of-day in the hero — date
        // only. ISO strings shorter than 10 chars stay as-is (defensive).
        assertEquals(
            "submitted 2025-04-12",
            founderReviewSubtitle(null, "2025-04-12T23:59:59+05:30"),
        )
        assertEquals("submitted 2025", founderReviewSubtitle(null, "2025"))
    }
}
