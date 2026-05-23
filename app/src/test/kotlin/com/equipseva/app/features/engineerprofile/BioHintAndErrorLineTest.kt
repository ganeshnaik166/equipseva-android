package com.equipseva.app.features.engineerprofile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BioHintAndErrorLineTest {

    // ---- bioHintLine -------------------------------------------------

    @Test fun `under-min length shows count slash min plus more-to-go`() {
        assertEquals(
            "5/20 characters — 15 more to go",
            bioHintLine(5, 20),
        )
    }

    @Test fun `at-zero length shows full deficit`() {
        assertEquals(
            "0/20 characters — 20 more to go",
            bioHintLine(0, 20),
        )
    }

    @Test fun `one short of min shows 1 more to go`() {
        assertEquals(
            "19/20 characters — 1 more to go",
            bioHintLine(19, 20),
        )
    }

    @Test fun `exactly at min flips to long-form hint with hospitals motivation`() {
        // Boundary — inclusive on the long-form branch.
        assertEquals(
            "20 characters. Hospitals see this on your profile.",
            bioHintLine(20, 20),
        )
    }

    @Test fun `above min stays on long-form hint`() {
        assertEquals(
            "100 characters. Hospitals see this on your profile.",
            bioHintLine(100, 20),
        )
    }

    @Test fun `em-dash in short-form is U+2014 not U+2013 en-dash`() {
        val out = bioHintLine(5, 20)
        assertTrue(out.contains('—'))
        assertEquals(false, out.contains('–'))
    }

    @Test fun `period before Hospitals in long-form is mandatory`() {
        // Pin so a refactor that dropped the period (just "N
        // characters Hospitals see…") doesn't slip in.
        val out = bioHintLine(20, 20)
        assertTrue(out.contains("characters. Hospitals"))
    }

    // ---- bioErrorLine ------------------------------------------------

    @Test fun `empty bio returns null (no error before typing)`() {
        // Critical pin — error fires only after engineer starts typing.
        assertNull(bioErrorLine(bioLen = 0, bioNonEmpty = false, minLen = 20))
    }

    @Test fun `under-min length with non-empty field returns error`() {
        assertEquals(
            "Bio must be at least 20 characters",
            bioErrorLine(bioLen = 5, bioNonEmpty = true, minLen = 20),
        )
    }

    @Test fun `whitespace-only bio (non-empty but trims to 0) still errors`() {
        // Pin the bioLen < minLen gate (caller trims first).
        // bioLen = 0 (trimmed), bioNonEmpty = true (raw has spaces).
        assertEquals(
            "Bio must be at least 20 characters",
            bioErrorLine(bioLen = 0, bioNonEmpty = true, minLen = 20),
        )
    }

    @Test fun `at-min length returns null (no error)`() {
        // Boundary — inclusive on no-error side.
        assertNull(bioErrorLine(bioLen = 20, bioNonEmpty = true, minLen = 20))
    }

    @Test fun `above-min returns null`() {
        assertNull(bioErrorLine(bioLen = 100, bioNonEmpty = true, minLen = 20))
    }

    @Test fun `under-min length but empty field returns null (don't error before typing)`() {
        // This is the inverse of the at-min case — explicitly checks
        // the empty-field short-circuit.
        assertNull(bioErrorLine(bioLen = 5, bioNonEmpty = false, minLen = 20))
    }
}
