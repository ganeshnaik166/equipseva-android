package com.equipseva.app.features.repair

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1447 pre-visit engineer dossier helpers. */
class PvedHelpersTest {

    @Test fun `verification pill maps known states (case-insensitive)`() {
        assertEquals("Verified" to PillKind.Success, pvedVerificationPill("verified"))
        assertEquals("Verified" to PillKind.Success, pvedVerificationPill("VERIFIED"))
        assertEquals("Pending" to PillKind.Warn, pvedVerificationPill("pending"))
        assertEquals("Rejected" to PillKind.Danger, pvedVerificationPill("rejected"))
    }

    @Test fun `unknown verification de-snakes with Neutral, blank falls back`() {
        assertEquals("On hold" to PillKind.Neutral, pvedVerificationPill("on_hold"))
        assertEquals("Unknown" to PillKind.Neutral, pvedVerificationPill(""))
    }

    @Test fun `rating label stars one decimal, null reads no ratings`() {
        assertEquals("No ratings yet", pvedRatingLabel(null))
        assertEquals("★ 5", pvedRatingLabel(5.0))
        assertEquals("★ 4.7", pvedRatingLabel(4.66))
    }
}
