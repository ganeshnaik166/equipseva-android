package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the four pure helpers behind the founder's integrity-flag row.
 */
class IntegrityRowHelpersTest {

    // ---- integrityActionLabel ----------------------------------------

    @Test fun `non-null action passes through verbatim`() {
        assertEquals("launch", integrityActionLabel("launch"))
        assertEquals("request_signed", integrityActionLabel("request_signed"))
    }

    @Test fun `null action falls back to lowercase unknown action`() {
        // Critical pin — the fallback is lowercase to flow with the
        // surrounding action codes (which are lowercase snake_case).
        assertEquals("unknown action", integrityActionLabel(null))
    }

    @Test fun `empty action passes through verbatim, not folded`() {
        // Pin the exact null-only gate — a refactor to isNullOrBlank
        // would silently mask backfill rows that store "".
        assertEquals("", integrityActionLabel(""))
    }

    // ---- integrityRowTimestampLabel ----------------------------------

    @Test fun `relative label wins when non-null`() {
        assertEquals(
            "2 hours ago",
            integrityRowTimestampLabel("2026-05-23T09:30:00Z", "2 hours ago"),
        )
    }

    @Test fun `null relative label falls back to ISO date prefix`() {
        // take(10) strips time + tz and gives the founder a stable
        // date key. Pin the exact 10-char slice.
        assertEquals(
            "2026-05-23",
            integrityRowTimestampLabel("2026-05-23T09:30:00Z", null),
        )
    }

    @Test fun `short raw string is left intact on relative-null fallback`() {
        // take(10) on shorter string returns the original.
        assertEquals("abc", integrityRowTimestampLabel("abc", null))
    }

    // ---- verdictChipText ---------------------------------------------

    @Test fun `verdict chip joins label and value with colon-space`() {
        assertEquals(
            "device: clean",
            verdictChipText("device", "clean"),
        )
    }

    @Test fun `verdict chip uses em-dash for null value`() {
        // Critical pin — em-dash (U+2014) is the project convention.
        // A refactor to "N/A" or "—" (en-dash U+2013) would clash
        // with [textOrDash] elsewhere.
        assertEquals(
            "device: —",
            verdictChipText("device", null),
        )
    }

    @Test fun `verdict chip uses em-dash for blank value`() {
        assertEquals("lic: —", verdictChipText("lic", "   "))
        assertEquals("app: —", verdictChipText("app", ""))
    }

    @Test fun `verdict em-dash is U+2014 not U+2013 en-dash`() {
        val text = verdictChipText("device", null)
        assertTrue(text.contains('—'))
        assertEquals(false, text.contains('–'))
    }

    // ---- integrityPassFailPillTextAndKind ----------------------------

    @Test fun `pass true reads PASS with Success`() {
        // All-caps is intentional — mirrors the server log shape.
        assertEquals(
            "PASS" to PillKind.Success,
            integrityPassFailPillTextAndKind(true),
        )
    }

    @Test fun `pass false reads FAIL with Danger`() {
        assertEquals(
            "FAIL" to PillKind.Danger,
            integrityPassFailPillTextAndKind(false),
        )
    }
}
