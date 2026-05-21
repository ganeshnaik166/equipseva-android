package com.equipseva.app.features.amc

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC-contract status → (label, [PillKind]) mapping behind
 * the maintenance-contracts list pill. Two tone choices worth
 * defending:
 *   * `paused` and `renewal_failed` both Danger — surfaces these as
 *     "needs attention" rather than soft Neutral.
 *   * `expired` and `cancelled` both Neutral — terminal but
 *     non-actionable; the hospital can renew later.
 *
 * Case-insensitive matching means a future server-side mixed-case
 * write doesn't fall through to the title-case fallback.
 */
class AmcStatusLabelAndKindTest {

    @Test fun `active renders Success`() {
        assertEquals("Active" to PillKind.Success, amcStatusLabelAndKind("active"))
    }

    @Test fun `paused renders Danger (needs attention)`() {
        assertEquals("Paused" to PillKind.Danger, amcStatusLabelAndKind("paused"))
    }

    @Test fun `expired renders Neutral (terminal but non-actionable)`() {
        assertEquals("Expired" to PillKind.Neutral, amcStatusLabelAndKind("expired"))
    }

    @Test fun `cancelled renders Neutral`() {
        assertEquals("Cancelled" to PillKind.Neutral, amcStatusLabelAndKind("cancelled"))
    }

    @Test fun `renewal_failed renders the two-word label with Danger`() {
        // Pin the underscored wire key → human-readable copy mapping.
        assertEquals(
            "Renewal failed" to PillKind.Danger,
            amcStatusLabelAndKind("renewal_failed"),
        )
    }

    @Test fun `case-insensitive matching keeps known keys mapped`() {
        assertEquals(
            "Active" to PillKind.Success,
            amcStatusLabelAndKind("ACTIVE"),
        )
        assertEquals(
            "Renewal failed" to PillKind.Danger,
            amcStatusLabelAndKind("Renewal_Failed"),
        )
    }

    @Test fun `unknown status falls back to first-letter-capitalised label and Neutral tone`() {
        // Forward-compat — a future server-side state surfaces with
        // SOMETHING readable + neutral colour, rather than crashing.
        assertEquals(
            "Future_state" to PillKind.Neutral,
            amcStatusLabelAndKind("future_state"),
        )
    }

    @Test fun `empty status returns empty label + Neutral`() {
        // Defensive — the empty-string row shouldn't crash the card.
        // replaceFirstChar on an empty string is a no-op.
        assertEquals("" to PillKind.Neutral, amcStatusLabelAndKind(""))
    }
}
