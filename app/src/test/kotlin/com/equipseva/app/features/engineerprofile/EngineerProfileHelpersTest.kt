package com.equipseva.app.features.engineerprofile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two pure helpers in [EngineerProfileViewModel] used by the
 * profile editor:
 *
 *   * [parseList] normalises a comma-separated text field (service
 *     areas + specializations) into a clean List<String>. Used both
 *     by the validate-before-submit gate and by the actual upsert
 *     payload — a regression that misparses would silently let through
 *     blank entries and the empty-state ban-gate.
 *
 *   * [formatRate] strips the trailing ".0" from whole-rupee rate
 *     values so the editor field reads "75" instead of "75.0" on
 *     re-hydration — but preserves "75.5" so the rate isn't silently
 *     truncated.
 */
class EngineerProfileHelpersTest {

    // ---- parseList ----

    @Test fun `parseList splits on comma, trims, and drops blanks`() {
        assertEquals(
            listOf("Bengaluru", "Mysuru", "Tumakuru"),
            parseList(" Bengaluru, Mysuru , Tumakuru  "),
        )
    }

    @Test fun `parseList drops empty entries from trailing or duplicate commas`() {
        assertEquals(
            listOf("Bengaluru"),
            parseList("Bengaluru,,,"),
        )
    }

    @Test fun `parseList yields empty list for blank input`() {
        assertTrue(parseList("").isEmpty())
        assertTrue(parseList("   ").isEmpty())
        assertTrue(parseList(",,, ,").isEmpty())
    }

    @Test fun `parseList preserves duplicates — dedupe is the caller's job`() {
        // Document the contract: the parser is split+trim, not a set.
        // Specialization picker dedupes; service-area field doesn't.
        assertEquals(
            listOf("A", "A", "B"),
            parseList("A, A, B"),
        )
    }

    // ---- formatRate ----

    @Test fun `formatRate strips trailing dot-zero for whole-rupee value`() {
        assertEquals("75", formatRate(75.0))
        assertEquals("0", formatRate(0.0))
    }

    @Test fun `formatRate preserves fractional rupee value`() {
        assertEquals("75.5", formatRate(75.5))
        assertEquals("0.25", formatRate(0.25))
    }

    @Test fun `formatRate handles negative whole and fractional values`() {
        // Defensive — negative rate is invalid at the form layer, but
        // the formatter should at least round-trip rather than throw.
        assertEquals("-10", formatRate(-10.0))
        assertEquals("-10.5", formatRate(-10.5))
    }
}
