package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

class ReportRowHelpersTest {

    // ---- reportRowReporterDisplay ------------------------------------

    @Test fun `non-null reporter name wins`() {
        assertEquals(
            "Asha Rao",
            reportRowReporterDisplay("Asha Rao", "uid-abcdefgh-ijkl"),
        )
    }

    @Test fun `null reporter name falls back to first 8 chars of userId`() {
        // Critical pin — take(8), matches the founder's other 8-char
        // ID prefix patterns (lookup keys for Supabase Studio).
        assertEquals(
            "uid-abcd",
            reportRowReporterDisplay(null, "uid-abcdefgh-ijkl"),
        )
    }

    @Test fun `empty reporter name passes through verbatim (not folded)`() {
        // Pin exact null gate. Empty-string reporter name is preserved
        // (the wire shouldn't allow this, but pin total-function shape).
        assertEquals("", reportRowReporterDisplay("", "uid-anything"))
    }

    @Test fun `short userId is left intact under the prefix fallback`() {
        // take(8) on shorter string returns the original.
        assertEquals("uid", reportRowReporterDisplay(null, "uid"))
    }

    // ---- reportRowTargetIdSlug ---------------------------------------

    @Test fun `target id last 8 chars`() {
        // Critical pin — takeLast(8) NOT take(8). Heterogeneous IDs
        // are more entropic at the suffix.
        assertEquals(
            "ghijklmn",
            reportRowTargetIdSlug("abcdefghijklmn"),
        )
    }

    @Test fun `short target id is left intact`() {
        // takeLast(8) on shorter string returns the original.
        assertEquals("xyz", reportRowTargetIdSlug("xyz"))
    }

    @Test fun `exactly 8-char id passes through verbatim`() {
        assertEquals("abcdefgh", reportRowTargetIdSlug("abcdefgh"))
    }

    @Test fun `cross-helper invariant — reporter prefix vs target suffix`() {
        // Pin the asymmetry. Reporter uses take(8) because user IDs
        // share a common prefix convention; target uses takeLast(8)
        // because target IDs span heterogeneous tables.
        val id = "abcdefghijklmnop"
        assertEquals("abcdefgh", reportRowReporterDisplay(null, id))
        assertEquals("ijklmnop", reportRowTargetIdSlug(id))
    }
}
