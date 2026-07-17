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

    @Test fun `only closed reads N closed`() {
        // r1457: the completedJobs bucket holds Completed AND Cancelled jobs,
        // so the label is "closed" — "completed"/"done" mislabeled cancelled.
        assertEquals("5 closed", activeWorkSubtitle(0, 5))
    }

    @Test fun `both lists reads X in progress dot Y closed`() {
        // Critical pin — per-bucket counts. Previous behaviour used
        // combined.size for "in progress" which miscounted completed rows.
        assertEquals(
            "3 in progress · 5 closed",
            activeWorkSubtitle(3, 5),
        )
    }

    @Test fun `combined form uses closed not done`() {
        val out = activeWorkSubtitle(3, 5)
        assertEquals(true, out!!.endsWith(" closed"))
    }

    @Test fun `no bucket label calls cancelled jobs done or completed`() {
        // r1457 regression pin: cancelled jobs land in completedCount, so the
        // subtitle must never assert "done"/"completed".
        val out = activeWorkSubtitle(3, 5)!!
        assertEquals(false, out.contains("done"))
        assertEquals(false, out.contains("completed"))
    }

    @Test fun `1 in progress 0 closed reads 1 in progress`() {
        assertEquals("1 in progress", activeWorkSubtitle(1, 0))
    }

    @Test fun `0 in progress 1 closed reads 1 closed`() {
        assertEquals("1 closed", activeWorkSubtitle(0, 1))
    }

    @Test fun `large counts interpolate verbatim`() {
        assertEquals(
            "42 in progress · 100 closed",
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
