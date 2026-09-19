package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the expiry phrase on the hospital home AMC chip.
 *
 * Critical regression target: a lapsed contract (negative days remaining)
 * used to fall into the `<= 0` branch and read "expires today", telling the
 * hospital its cover was still live on a day it had already ended. That chip
 * is the only AMC signal on the landing screen, so the wrong word there is
 * the difference between renewing and not.
 *
 * Second pin: the far and unparseable branches must not print the raw server
 * value. They used to render "2027-03-05" verbatim.
 */
class AmcChipExpiryLineTest {

    @Test fun `already expired reads as expired not as expiring today`() {
        val line = amcChipExpiryLine(-3L, "2026-09-01")
        assertTrue("expected an expired phrase, got: $line", line.startsWith("expired"))
        assertTrue("must not claim today", !line.contains("today"))
    }

    @Test fun `one day past expiry is still expired`() {
        // Boundary pin on the other side of zero.
        assertTrue(amcChipExpiryLine(-1L, "2026-09-01").startsWith("expired"))
    }

    @Test fun `zero days remaining is expires today`() {
        assertEquals("expires today", amcChipExpiryLine(0L, "2026-09-18"))
    }

    @Test fun `one day remaining is singular`() {
        // "expires in 1 days" is the classic plural slip, and the last day
        // before expiry is exactly when the copy gets read.
        assertEquals("expires in 1 day", amcChipExpiryLine(1L, "2026-09-19"))
    }

    @Test fun `inside the thirty day window counts down in days`() {
        assertEquals("expires in 7 days", amcChipExpiryLine(7L, "2026-09-25"))
        assertEquals("expires in 30 days", amcChipExpiryLine(30L, "2026-10-18"))
    }

    @Test fun `beyond thirty days shows a formatted date not the raw ISO value`() {
        val line = amcChipExpiryLine(180L, "2027-03-05")
        assertTrue("raw ISO leaked into the UI: $line", !line.contains("2027-03-05"))
        assertTrue("expected a formatted date, got: $line", line.contains("Mar 2027"))
    }

    @Test fun `unparseable end date still renders a date rather than a countdown`() {
        // daysLeft is null when LocalDate.parse failed upstream; the chip must
        // still say something, and prettyDate degrades to its own fallback.
        val line = amcChipExpiryLine(null, "2027-03-05")
        assertTrue("expected a formatted date, got: $line", line.contains("Mar 2027"))
    }

    @Test fun `the thirty and thirty one day boundary switches phrasing`() {
        assertTrue(amcChipExpiryLine(30L, "2026-10-18").contains("30 days"))
        assertTrue(!amcChipExpiryLine(31L, "2026-10-19").contains("31 days"))
    }
}
