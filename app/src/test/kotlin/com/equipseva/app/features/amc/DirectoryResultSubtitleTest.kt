package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins the r1428 engineer-pick-row subtitle for the add-fallback picker. */
class DirectoryResultSubtitleTest {

    @Test fun `all parts present join with middle dots`() {
        assertEquals("Pune · ★ 4.5 · 12 jobs", directoryResultSubtitle("Pune", 4.5, 12))
    }

    @Test fun `whole-number rating drops decimal`() {
        assertEquals("Pune · ★ 5 · 3 jobs", directoryResultSubtitle("Pune", 5.0, 3))
    }

    @Test fun `missing city and zero rating still reads job count`() {
        assertEquals("0 jobs", directoryResultSubtitle(null, 0.0, 0))
        assertEquals("7 jobs", directoryResultSubtitle("  ", 0.0, 7))
    }

    @Test fun `city with no rating`() {
        assertEquals("Mumbai · 4 jobs", directoryResultSubtitle("Mumbai", 0.0, 4))
    }
}
