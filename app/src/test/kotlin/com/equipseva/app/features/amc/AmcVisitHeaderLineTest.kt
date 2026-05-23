package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC visit-row header line format ("Visit #N · RPR-NNNN").
 * Falls back gracefully:
 *  * missing visit number → "-" placeholder (legacy pre-numbering rows)
 *  * missing job number → trailing " · " trimmed off
 *
 * Pin so a refactor that "cleans up" the trim() doesn't accidentally
 * leave a dangling " · " for visits whose job-number hasn't loaded.
 */
class AmcVisitHeaderLineTest {

    @Test fun `both number and job-number render together`() {
        assertEquals(
            "Visit #3 · RPR-00042",
            amcVisitHeaderLine(amcVisitNumber = 3, jobNumber = "RPR-00042"),
        )
    }

    @Test fun `missing visit number renders dash placeholder`() {
        assertEquals(
            "Visit #- · RPR-00042",
            amcVisitHeaderLine(amcVisitNumber = null, jobNumber = "RPR-00042"),
        )
    }

    @Test fun `missing job number trims the trailing middle-dot`() {
        // Critical: without the trim, a null jobNumber would surface
        // as "Visit #3 · " — pin so the trailing separator doesn't
        // bleed through.
        assertEquals(
            "Visit #3",
            amcVisitHeaderLine(amcVisitNumber = 3, jobNumber = null),
        )
    }

    @Test fun `blank string jobNumber gets the same trim treatment`() {
        // Defensive: an empty-string wire value behaves the same as
        // null.
        assertEquals(
            "Visit #3",
            amcVisitHeaderLine(amcVisitNumber = 3, jobNumber = ""),
        )
    }

    @Test fun `both missing renders just dash`() {
        assertEquals(
            "Visit #-",
            amcVisitHeaderLine(amcVisitNumber = null, jobNumber = null),
        )
    }

    @Test fun `large visit numbers render as-is`() {
        // No artificial cap on the visit counter.
        assertEquals(
            "Visit #999 · RPR-12345678",
            amcVisitHeaderLine(amcVisitNumber = 999, jobNumber = "RPR-12345678"),
        )
    }

    @Test fun `header uses U+00B7 middle dot (not ASCII)`() {
        val line = amcVisitHeaderLine(amcVisitNumber = 1, jobNumber = "RPR-1")
        // Exactly one middle-dot separator.
        assertEquals(1, line.count { it == '·' })
    }
}
