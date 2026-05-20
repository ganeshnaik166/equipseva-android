package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Pins ChatScreen's pure presentation helpers — avatar initials,
 * day-grouping key, day-label fallback chain, image-URL detector.
 * These run on every message row + day separator and a regression
 * either shows the wrong avatar text or hides the day header.
 */
class ChatScreenHelpersTest {

    private val zone: ZoneId = ZoneId.of("Asia/Kolkata")
    private val today: LocalDate = LocalDate.parse("2026-05-20")
    private val formatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM").withZone(zone)

    // --- initials ---

    @Test fun `initialsOf takes first letter of first two words`() {
        assertEquals("RD", chatInitialsOf("Ravi Dhanavath"))
        assertEquals("GD", chatInitialsOf("Ganesh Dhanavath"))
    }

    @Test fun `initialsOf upper-cases lowercase input`() {
        assertEquals("RD", chatInitialsOf("ravi dhanavath"))
    }

    @Test fun `initialsOf caps at two characters`() {
        // limit=2 in the split → never sees the third word.
        assertEquals("AB", chatInitialsOf("Anita Bose Choudhury"))
    }

    @Test fun `initialsOf takes single initial for one-word name`() {
        assertEquals("R", chatInitialsOf("Ravi"))
    }

    @Test fun `initialsOf falls back to ? for blank or whitespace`() {
        assertEquals("?", chatInitialsOf(""))
        assertEquals("?", chatInitialsOf("   "))
    }

    // --- dayKey ---

    @Test fun `dayKey returns the local-zone date for a valid iso`() {
        assertEquals(
            "2026-05-20",
            chatDayKey("2026-05-20T10:00:00Z", zone),
        )
    }

    @Test fun `dayKey collapses null and unparseable timestamps to unknown`() {
        assertEquals("unknown", chatDayKey(null, zone))
        assertEquals("unknown", chatDayKey("yesterday", zone))
        assertEquals("unknown", chatDayKey("", zone))
    }

    @Test fun `dayKey respects the supplied zone over the default`() {
        // 2026-05-21T01:00Z falls on 2026-05-21 in IST (+05:30) and
        // on 2026-05-20 in PST (-07:00). Pin both so a refactor that
        // hard-codes systemDefault is caught.
        val iso = "2026-05-21T01:00:00Z"
        assertEquals("2026-05-21", chatDayKey(iso, ZoneId.of("Asia/Kolkata")))
        assertEquals("2026-05-20", chatDayKey(iso, ZoneId.of("America/Los_Angeles")))
    }

    // --- dayLabel ---

    @Test fun `dayLabel maps today and yesterday to friendly strings`() {
        assertEquals("Today", chatDayLabel("2026-05-20", today, zone, formatter))
        assertEquals("Yesterday", chatDayLabel("2026-05-19", today, zone, formatter))
    }

    @Test fun `dayLabel formats older dates with the supplied formatter`() {
        assertEquals(
            "01 May",
            chatDayLabel("2026-05-01", today, zone, formatter),
        )
    }

    @Test fun `dayLabel returns empty for unknown or malformed key`() {
        // The day-separator renders nothing on a blank label.
        assertEquals("", chatDayLabel("unknown", today, zone, formatter))
        assertEquals("", chatDayLabel("not-a-date", today, zone, formatter))
        assertEquals("", chatDayLabel("", today, zone, formatter))
    }

    // --- isImageUrlExtension ---

    @Test fun `isImageUrlExtension accepts the six supported types`() {
        assertTrue("https://x/a.jpg".isImageUrlExtension())
        assertTrue("https://x/a.JPEG".isImageUrlExtension())
        assertTrue("https://x/a.png".isImageUrlExtension())
        assertTrue("https://x/a.webp".isImageUrlExtension())
        assertTrue("https://x/a.gif".isImageUrlExtension())
        assertTrue("https://x/a.heic".isImageUrlExtension())
    }

    @Test fun `isImageUrlExtension strips query string before matching`() {
        // Supabase signed URLs always carry `?token=...` — pin that the
        // check still recognises the underlying object key.
        assertTrue("https://x/a.jpg?token=abc&expires=123".isImageUrlExtension())
    }

    @Test fun `isImageUrlExtension rejects pdf and other non-image types`() {
        assertFalse("https://x/a.pdf".isImageUrlExtension())
        assertFalse("https://x/a.txt".isImageUrlExtension())
        assertFalse("https://x/a".isImageUrlExtension())
    }
}
