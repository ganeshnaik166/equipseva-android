package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the four helpers behind the founder's AMC-escalation triage row
 * (hospital-name fallback, reason prose, pill text/kind, context
 * subline). These are the load-bearing UI surfaces the founder uses to
 * decide whether to manually re-assign an engineer or escalate to the
 * hospital.
 */
class AmcEscalationRowHelpersTest {

    // ---- amcEscalationHospitalName -----------------------------------

    @Test fun `hospital name passes through when non-blank`() {
        assertEquals(
            "Apollo Hyderabad",
            amcEscalationHospitalName("Apollo Hyderabad"),
        )
    }

    @Test fun `null hospital name falls back to role label`() {
        // Backfill rows or RLS-trimmed projections can land here with
        // null hospitalName. Pin the fallback so the row still reads
        // as an actionable item, not "·" with a blank.
        assertEquals("Hospital", amcEscalationHospitalName(null))
    }

    @Test fun `blank hospital name falls back to role label`() {
        assertEquals("Hospital", amcEscalationHospitalName(""))
        assertEquals("Hospital", amcEscalationHospitalName("   "))
    }

    // ---- amcEscalationReasonLabel ------------------------------------

    @Test fun `snake case reason gets spaces and first-letter capital`() {
        assertEquals(
            "Rotation exhausted",
            amcEscalationReasonLabel("rotation_exhausted"),
        )
    }

    @Test fun `multi-underscore reason replaces all underscores with spaces`() {
        // Critical pin — a refactor that used replaceFirst('_') would
        // surface "Engineer unavailable_today".
        assertEquals(
            "Engineer unavailable today",
            amcEscalationReasonLabel("engineer_unavailable_today"),
        )
    }

    @Test fun `single-word reason still gets first-letter capitalised`() {
        assertEquals("Other", amcEscalationReasonLabel("other"))
    }

    @Test fun `already-capitalised reason is idempotent`() {
        // replaceFirstChar with uppercase() on an already-uppercase
        // letter is a no-op — pin so a refactor doesn't lower-then-
        // upper and accidentally introduce a bug on a non-snake input.
        assertEquals("Other", amcEscalationReasonLabel("Other"))
    }

    @Test fun `empty reason returns empty string`() {
        // Defensive — the wire CHECK constraint forbids empty, but
        // pin the total-function shape so a refactor doesn't add a
        // null/empty branch.
        assertEquals("", amcEscalationReasonLabel(""))
    }

    // ---- amcEscalationPillTextAndKind --------------------------------

    @Test fun `rotation_exhausted reads Exhausted with Danger`() {
        // Critical regression target — this is the ONLY Danger code.
        // A refactor that renamed the wire string would silently
        // downgrade the urgency cue.
        assertEquals(
            "Exhausted" to PillKind.Danger,
            amcEscalationPillTextAndKind("rotation_exhausted"),
        )
    }

    @Test fun `engineer_unavailable reads Open with Warn`() {
        assertEquals(
            "Open" to PillKind.Warn,
            amcEscalationPillTextAndKind("engineer_unavailable"),
        )
    }

    @Test fun `parts_delayed reads Open with Warn`() {
        assertEquals(
            "Open" to PillKind.Warn,
            amcEscalationPillTextAndKind("parts_delayed"),
        )
    }

    @Test fun `unknown reason reads Open with Warn (forward-compat)`() {
        // A new wire code that the client doesn't recognise yet falls
        // through to Warn — pin the open-set default so a new server
        // reason doesn't crash or render as Danger.
        assertEquals(
            "Open" to PillKind.Warn,
            amcEscalationPillTextAndKind("some_future_code"),
        )
    }

    @Test fun `case-sensitive gate — Rotation_Exhausted does not match`() {
        // Pin the exact-match shape — the wire CHECK is lowercase
        // snake_case. A refactor to case-insensitive would mask a
        // server-side enum drift.
        assertEquals(
            "Open" to PillKind.Warn,
            amcEscalationPillTextAndKind("Rotation_Exhausted"),
        )
    }

    // ---- amcEscalationContextLine ------------------------------------

    @Test fun `with visit number renders visit hash + middle-dot + contract prefix`() {
        assertEquals(
            "Visit #3 · contract abc12345",
            amcEscalationContextLine(3, "abc12345xyz9999"),
        )
    }

    @Test fun `middle dot is the U+00B7 codepoint not ASCII period`() {
        // Pin glyph — a refactor that normalised to "." would soften
        // the visual separation and clash with the founder's other
        // ops queues that all use U+00B7.
        val line = amcEscalationContextLine(1, "deadbeef0000")
        assertTrue(line.contains('·'))
    }

    @Test fun `contract id is truncated to 8 chars`() {
        // The founder uses the 8-char prefix to cross-reference the
        // AMC detail screen — pin take(8), not take(6) or take(10).
        assertEquals(
            "Visit #1 · contract abcdefgh",
            amcEscalationContextLine(1, "abcdefghijklmnop"),
        )
    }

    @Test fun `null visit number drops the visit prefix`() {
        // An escalation raised against a contract before any visits
        // were scheduled — pin the no-visit branch.
        assertEquals(
            "Contract abcdefgh",
            amcEscalationContextLine(null, "abcdefghijklmnop"),
        )
    }

    @Test fun `null visit branch capitalises Contract`() {
        // The two branches use different casing: "Visit #N · contract"
        // (lowercase 'contract' as second token of a sentence) vs
        // "Contract XXXXXXXX" (uppercase 'C' as sentence-start). Pin
        // both so a refactor that unified them surfaces here.
        assertTrue(amcEscalationContextLine(null, "abcdefgh").startsWith("Contract "))
        assertTrue(amcEscalationContextLine(5, "abcdefgh").contains(" contract "))
    }

    @Test fun `contract id shorter than 8 chars is left intact`() {
        // take(N) on a string shorter than N returns the original —
        // pin so a refactor to substring(0, 8) (which would throw)
        // surfaces here.
        assertEquals(
            "Visit #2 · contract short",
            amcEscalationContextLine(2, "short"),
        )
        assertEquals(
            "Contract short",
            amcEscalationContextLine(null, "short"),
        )
    }

    @Test fun `visit number 0 still renders the visit prefix`() {
        // Zero is a valid visit ordinal (some surfaces use 0-indexed
        // initial-site-visit). Pin so a refactor to `visitNumber > 0`
        // surfaces here as a behaviour change.
        assertEquals(
            "Visit #0 · contract abcdefgh",
            amcEscalationContextLine(0, "abcdefghxyz"),
        )
    }

    @Test fun `large visit number interpolates verbatim`() {
        assertEquals(
            "Visit #42 · contract abcdefgh",
            amcEscalationContextLine(42, "abcdefghxyz"),
        )
    }
}
