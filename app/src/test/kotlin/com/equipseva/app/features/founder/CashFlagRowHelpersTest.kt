package com.equipseva.app.features.founder

import com.equipseva.app.core.util.prettyDateTime
import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the four helpers behind the founder's cash-flag history row.
 * Critical surface: the asked_cash → Cash asked + Danger gate — this
 * is the founder's primary signal for an engineer-suspension call,
 * and the wire string is fixed by a CHECK constraint server-side.
 */
class CashFlagRowHelpersTest {

    // ---- cashFlagResponsePillTextAndKind -----------------------------

    @Test fun `asked_cash maps to Cash asked with Danger`() {
        // Critical regression target.
        assertEquals(
            "Cash asked" to PillKind.Danger,
            cashFlagResponsePillTextAndKind("asked_cash"),
        )
    }

    @Test fun `no_cash maps to No cash with Success`() {
        assertEquals(
            "No cash" to PillKind.Success,
            cashFlagResponsePillTextAndKind("no_cash"),
        )
    }

    @Test fun `declined maps to Declined with Default (not Warn)`() {
        // Pin Default — declined means "no response", a neutral
        // signal. A refactor that escalated this to Warn would
        // visually bias the founder against survey non-responders.
        assertEquals(
            "Declined" to PillKind.Default,
            cashFlagResponsePillTextAndKind("declined"),
        )
    }

    @Test fun `unknown wire string falls through to raw text + Default`() {
        // Forward-compat — a new CHECK enum value renders raw.
        assertEquals(
            "some_future_code" to PillKind.Default,
            cashFlagResponsePillTextAndKind("some_future_code"),
        )
    }

    @Test fun `case-sensitive — Asked_Cash falls through to raw + Default`() {
        // Pin exact-match. The wire CHECK is lowercase; case-
        // insensitive matching would mask a server-side enum drift.
        assertEquals(
            "Asked_Cash" to PillKind.Default,
            cashFlagResponsePillTextAndKind("Asked_Cash"),
        )
    }

    @Test fun `empty wire string falls through to empty raw + Default`() {
        // Defensive — server CHECK forbids empty, but pin total shape.
        assertEquals(
            "" to PillKind.Default,
            cashFlagResponsePillTextAndKind(""),
        )
    }

    // ---- cashFlagRowTitle --------------------------------------------

    @Test fun `server jobNumber wins when present`() {
        assertEquals(
            "RPR-2026-00099",
            cashFlagRowTitle("RPR-2026-00099", "abcdefghijkl"),
        )
    }

    @Test fun `null jobNumber falls back to RPR plus 6-char id prefix`() {
        assertEquals(
            "RPR-abcdef",
            cashFlagRowTitle(null, "abcdefghijkl"),
        )
    }

    // ---- cashFlagRowHospitalLabel ------------------------------------

    @Test fun `non-blank hospital passes through`() {
        assertEquals(
            "Apollo Hyderabad",
            cashFlagRowHospitalLabel("Apollo Hyderabad"),
        )
    }

    @Test fun `null hospital falls back to Hospital`() {
        assertEquals("Hospital", cashFlagRowHospitalLabel(null))
    }

    @Test fun `blank hospital falls back to Hospital`() {
        assertEquals("Hospital", cashFlagRowHospitalLabel(""))
        assertEquals("Hospital", cashFlagRowHospitalLabel("   "))
    }

    // ---- cashFlagRespondedAtLabel ------------------------------------

    @Test fun `a UTC timestamp is shown in IST not sliced as wall-clock time`() {
        // Critical regression target: the label used to slice the first 16
        // characters and swap the 'T', so this instant displayed as
        // "2026-05-23 14:30" — 5.5 hours behind the time the founder's own
        // clock showed, with no zone marker, and disagreeing with the
        // prettyDateTime-formatted fields on the same card.
        assertEquals(
            "23 May 2026, 20:00",
            cashFlagRespondedAtLabel("2026-05-23T14:30:45Z"),
        )
    }

    @Test fun `an explicit IST offset is not shifted twice`() {
        assertEquals(
            "23 May 2026, 14:30",
            cashFlagRespondedAtLabel("2026-05-23T14:30:45+05:30"),
        )
    }

    @Test fun `the same instant renders identically wherever it appears`() {
        // The whole point of the change: one formatter across the card.
        val iso = "2026-05-23T14:30:45Z"
        assertEquals(prettyDateTime(iso), cashFlagRespondedAtLabel(iso))
    }

    @Test fun `T separator never reaches the UI`() {
        val out = cashFlagRespondedAtLabel("2026-05-23T14:30:45Z")
        assertEquals(false, out.contains('T'))
        assertTrue(out.contains(' '))
    }

    @Test fun `an unparseable payload degrades instead of throwing`() {
        // prettyDateTime's own fallback is the old sliced shape, so a bare
        // date or a malformed string still renders something.
        assertEquals("2026-05-23", cashFlagRespondedAtLabel("2026-05-23"))
        assertEquals("foo bar", cashFlagRespondedAtLabel("fooTbar"))
        assertEquals("2026-05-23 14:30", cashFlagRespondedAtLabel("2026-05-23T14:30"))
    }
}
