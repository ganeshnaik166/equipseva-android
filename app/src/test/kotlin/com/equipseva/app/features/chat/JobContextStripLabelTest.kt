package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Test

class JobContextStripLabelTest {

    @Test fun `non-blank job number passes through verbatim`() {
        assertEquals(
            "RPR-2026-00041",
            jobContextStripLabel("RPR-2026-00041", "uuid-abcd-1234"),
        )
    }

    @Test fun `null job number falls back to RJ- prefix + 8-char id`() {
        // Critical pin — "RJ-" prefix distinguishes from canonical "RPR-".
        // A founder inspecting a screenshot can tell this is the
        // in-flight chat fallback, not the real job number.
        assertEquals(
            "RJ-uuid-abc",
            jobContextStripLabel(null, "uuid-abcdefghijkl"),
        )
    }

    @Test fun `blank job number also falls back`() {
        assertEquals(
            "RJ-uuid-abc",
            jobContextStripLabel("", "uuid-abcdefghijkl"),
        )
        assertEquals(
            "RJ-uuid-abc",
            jobContextStripLabel("   ", "uuid-abcdefghijkl"),
        )
    }

    @Test fun `take 8 not take 6 (cross-id-prefix convention)`() {
        // Pin take(8) — matches userDisplayName / contract slug
        // conventions for cross-reference in Supabase Studio.
        val out = jobContextStripLabel(null, "abcdefghijklmnop")
        assertEquals("RJ-abcdefgh", out)
    }

    @Test fun `short job id passes through under take`() {
        // take(8) on shorter string returns the original.
        assertEquals("RJ-abc", jobContextStripLabel(null, "abc"))
    }

    @Test fun `RJ prefix distinct from RPR (regression target)`() {
        // Critical pin — a refactor that unified to "RPR-" prefix
        // would erase the distinction between canonical job number
        // and in-flight chat fallback. The "RJ-" prefix is a tell.
        val fallback = jobContextStripLabel(null, "uuid-1234")
        assertEquals(true, fallback.startsWith("RJ-"))
        assertEquals(false, fallback.startsWith("RPR-"))
    }
}
