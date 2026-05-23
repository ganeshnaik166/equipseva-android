package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InactiveEngineerVerifiedLineTest {

    @Test fun `composes Verified date middle-dot relative ago`() {
        assertEquals(
            "Verified 15 Jan 2026 · 4 months ago",
            inactiveEngineerVerifiedLine("15 Jan 2026", "4 months"),
        )
    }

    @Test fun `Verified prefix preserved verbatim`() {
        // Pin "Verified" (capital V) not "verified" or "KYC verified".
        val out = inactiveEngineerVerifiedLine("X", "Y")
        assertTrue(out.startsWith("Verified "))
    }

    @Test fun `ago suffix preserved verbatim`() {
        // Pin " ago" — without it the relative label reads as a
        // timestamp ("4 months" = when did it START? when did it END?).
        val out = inactiveEngineerVerifiedLine("X", "Y")
        assertTrue(out.endsWith(" ago"))
    }

    @Test fun `middle dot separator is U+00B7`() {
        val out = inactiveEngineerVerifiedLine("X", "Y")
        assertTrue(out.contains(" · "))
    }

    @Test fun `both inputs interpolate verbatim with no transformation`() {
        // Pin no casing/trim transformation on either side. Caller is
        // responsible for the input shape.
        assertEquals(
            "Verified 2026-05-23 · 3d ago",
            inactiveEngineerVerifiedLine("2026-05-23", "3d"),
        )
    }
}
