package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PartsOutliersSubtitleTest {

    @Test fun `non-empty list reads count plus 5x category avg`() {
        assertEquals(
            "5 >5x category avg",
            partsOutliersSubtitle(5),
        )
    }

    @Test fun `empty list returns null`() {
        assertNull(partsOutliersSubtitle(0))
    }

    @Test fun `5x threshold literal preserved verbatim`() {
        // Critical pin — server-side outlier query uses exactly 5x.
        // A refactor that relaxed to 4x or tightened to 6x without
        // updating server would surface as mismatch here.
        val out = partsOutliersSubtitle(1)
        assertTrue(out!!.endsWith(">5x category avg"))
    }

    @Test fun `subtitle uses ASCII gt + lowercase x distinct from row pill`() {
        // Pin the subtitle's bare integer form. The row pill uses
        // "%.1f×" with U+00D7 sign — different surface, different
        // typographic convention.
        val out = partsOutliersSubtitle(1)
        assertTrue(out!!.contains(">5x"))
        assertEquals(false, out.contains("×"))
    }

    @Test fun `1 row reads 1 plus 5x suffix (no plural noun)`() {
        // Noun-less subtitle — screen title supplies "outliers".
        assertEquals(
            "1 >5x category avg",
            partsOutliersSubtitle(1),
        )
    }
}
