package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the loading-state label on the Nearest sort chip.
 *
 * Critical: the AND gate — resolvingLocation alone isn't enough.
 * Stale coords + refresh-in-flight should NOT show the ellipsis
 * variant (we have a usable location already).
 */
class NearestSortChipLabelTest {

    @Test fun `resolving with no location shows ellipsis`() {
        assertEquals(
            "Nearest…",
            nearestSortChipLabel(resolvingLocation = true, hasLocation = false),
        )
    }

    @Test fun `resolving with existing location shows plain Nearest`() {
        // Critical pin — stale coords + refresh-in-flight shouldn't
        // surface "Nearest…". A refactor that gated only on
        // resolvingLocation would show ellipsis here.
        assertEquals(
            "Nearest",
            nearestSortChipLabel(resolvingLocation = true, hasLocation = true),
        )
    }

    @Test fun `not resolving with location shows plain Nearest`() {
        assertEquals(
            "Nearest",
            nearestSortChipLabel(resolvingLocation = false, hasLocation = true),
        )
    }

    @Test fun `not resolving without location shows plain Nearest`() {
        // Defensive — chip is functionally disabled in this case, but
        // pin the label stays plain (the surrounding "Enable location"
        // hint is what communicates the disabled state).
        assertEquals(
            "Nearest",
            nearestSortChipLabel(resolvingLocation = false, hasLocation = false),
        )
    }

    @Test fun `ellipsis is U+2026 single codepoint not three dots`() {
        // Pin the unicode glyph — diverging to "..." would clash
        // with rest-of-app loading conventions.
        val out = nearestSortChipLabel(resolvingLocation = true, hasLocation = false)
        assertTrue(out.contains('…'))
        assertEquals(false, out.contains("..."))
    }
}
