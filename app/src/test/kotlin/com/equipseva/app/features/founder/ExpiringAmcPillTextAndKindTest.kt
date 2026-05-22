package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the days-remaining → (text, PillKind) decision on the
 * founder's AMC-expiring-soon row.
 *
 * Critical region: 7-day boundary is INCLUSIVE for Danger. A
 * regression to ≤6 days for Danger would silently soften the
 * cadence-3 (1-day window) escalation that surfaces on the most
 * urgent rows. Pin so the hospital + founder see the SAME urgency
 * cue for the SAME contract (r353 cross-surface invariant).
 */
class ExpiringAmcPillTextAndKindTest {

    @Test fun `days less than 0 reads Expires today with Danger`() {
        // Negative days = clock skew / late-arriving row. Pin so
        // the helper treats it the same as 0 (already expired).
        assertEquals("Expires today" to PillKind.Danger, expiringAmcPillTextAndKind(-1))
    }

    @Test fun `0 days reads Expires today with Danger`() {
        assertEquals("Expires today" to PillKind.Danger, expiringAmcPillTextAndKind(0))
    }

    @Test fun `exactly 1 day reads 1 day left with Danger (singular)`() {
        // Critical singular split — pin so a refactor that always
        // appended "days" wouldn't surface "1 days left".
        assertEquals("1 day left" to PillKind.Danger, expiringAmcPillTextAndKind(1))
    }

    @Test fun `2 days reads N days left with Danger`() {
        assertEquals("2 days left" to PillKind.Danger, expiringAmcPillTextAndKind(2))
    }

    @Test fun `7 days (boundary) stays Danger`() {
        // Critical pin — 7 is the boundary, INCLUSIVE for Danger.
        // A refactor to ≤6 would silently soften the urgency cue
        // on the hospital's renewal-week banner.
        assertEquals("7 days left" to PillKind.Danger, expiringAmcPillTextAndKind(7))
    }

    @Test fun `8 days reads N days left with Warn (amber)`() {
        assertEquals("8 days left" to PillKind.Warn, expiringAmcPillTextAndKind(8))
    }

    @Test fun `30 days reads N days left with Warn`() {
        assertEquals("30 days left" to PillKind.Warn, expiringAmcPillTextAndKind(30))
    }

    @Test fun `large days remaining reads N days left with Warn (forward-compat)`() {
        // The query window is 30d but pin a sensible fallback if
        // a row slips past the filter.
        assertEquals("120 days left" to PillKind.Warn, expiringAmcPillTextAndKind(120))
    }

    @Test fun `singular branch fires exactly on 1 not on a range`() {
        // Pin the per-value text shape so a refactor that turned
        // ≤1 into the singular branch (would surface "0 day left"
        // on the 0-day path) surfaces in review.
        assertEquals("Expires today", expiringAmcPillTextAndKind(0).first)
        assertEquals("1 day left", expiringAmcPillTextAndKind(1).first)
        assertEquals("2 days left", expiringAmcPillTextAndKind(2).first)
    }
}
