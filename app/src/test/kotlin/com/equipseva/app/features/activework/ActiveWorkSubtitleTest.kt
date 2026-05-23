package com.equipseva.app.features.activework

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ActiveWorkSubtitleTest {

    @Test fun `both empty returns null`() {
        assertNull(activeWorkSubtitle(activeCount = 0, completedCount = 0))
    }

    @Test fun `only active reads N in progress`() {
        assertEquals("3 in progress", activeWorkSubtitle(3, 0))
    }

    @Test fun `only completed reads N completed (formal wire-status form)`() {
        // Pin "completed" not "done" — single-bucket uses formal form
        // matching the wire status name.
        assertEquals("5 completed", activeWorkSubtitle(0, 5))
    }

    @Test fun `both lists reads X in progress dot Y done`() {
        // Critical pin — per-bucket counts. Previous behaviour used
        // combined.size for "in progress" which miscounted completed
        // rows.
        assertEquals(
            "3 in progress · 5 done",
            activeWorkSubtitle(3, 5),
        )
    }

    @Test fun `combined form uses done not completed (line-fit)`() {
        // Pin "done" — shorter to fit on one line in the top bar.
        val out = activeWorkSubtitle(3, 5)
        assertEquals(true, out!!.endsWith(" done"))
    }

    @Test fun `1 in progress 0 completed reads 1 in progress`() {
        assertEquals("1 in progress", activeWorkSubtitle(1, 0))
    }

    @Test fun `0 in progress 1 completed reads 1 completed`() {
        assertEquals("1 completed", activeWorkSubtitle(0, 1))
    }

    @Test fun `large counts interpolate verbatim`() {
        assertEquals(
            "42 in progress · 100 done",
            activeWorkSubtitle(42, 100),
        )
    }

    @Test fun `middle dot is U+00B7`() {
        val out = activeWorkSubtitle(1, 1)
        assertEquals(true, out!!.contains(" · "))
    }

    @Test fun `negative defensive returns null when both invalid`() {
        // Pin <= 0 not == 0 — defensive against backfill bugs.
        assertNull(activeWorkSubtitle(-1, -1))
    }
}
