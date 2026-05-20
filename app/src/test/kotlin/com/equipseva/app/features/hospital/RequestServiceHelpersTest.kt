package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Pins the booking form's "Schedule" tile → date/slot resolution. The
 * server expects scheduled_date as an ISO-8601 date (YYYY-MM-DD) and
 * scheduled_time_slot from a small enum — a misresolve here silently
 * persists a wrong day or drops the slot entirely.
 */
class RequestServiceHelpersTest {

    private val today: LocalDate = LocalDate.parse("2026-05-20")
    private val zone: ZoneId = ZoneId.of("Asia/Kolkata")

    @Test fun `tile 0 maps to today evening`() {
        val out = resolveScheduledSlot(0, today, pickedDateMillis = null, zoneId = zone)
        assertEquals("2026-05-20" to "evening", out)
    }

    @Test fun `tile 1 maps to tomorrow morning`() {
        val out = resolveScheduledSlot(1, today, pickedDateMillis = null, zoneId = zone)
        assertEquals("2026-05-21" to "morning", out)
    }

    @Test fun `tile 2 maps to tomorrow afternoon`() {
        val out = resolveScheduledSlot(2, today, pickedDateMillis = null, zoneId = zone)
        assertEquals("2026-05-21" to "afternoon", out)
    }

    @Test fun `tile 3 is flexible with no date committed`() {
        val out = resolveScheduledSlot(3, today, pickedDateMillis = null, zoneId = zone)
        assertNull(out.first)
        assertEquals("flexible", out.second)
    }

    @Test fun `tile 4 with picker pinned uses any slot and the picked date`() {
        // 2026-05-25 in Asia/Kolkata
        val picked = ZonedDateTime.of(2026, 5, 25, 12, 0, 0, 0, zone)
            .toInstant().toEpochMilli()
        val out = resolveScheduledSlot(4, today, pickedDateMillis = picked, zoneId = zone)
        assertEquals("2026-05-25" to "any", out)
    }

    @Test fun `tile 4 with no picked millis emits null pair`() {
        val out = resolveScheduledSlot(4, today, pickedDateMillis = null, zoneId = zone)
        assertNull(out.first)
        assertNull(out.second)
    }

    @Test fun `default tile -1 emits null pair`() {
        val out = resolveScheduledSlot(-1, today, pickedDateMillis = null, zoneId = zone)
        assertNull(out.first)
        assertNull(out.second)
    }

    @Test fun `unknown tile values emit null pair`() {
        listOf(5, 99, Int.MAX_VALUE).forEach { slot ->
            val out = resolveScheduledSlot(slot, today, pickedDateMillis = null, zoneId = zone)
            assertNull("slot=$slot first", out.first)
            assertNull("slot=$slot second", out.second)
        }
    }

    @Test fun `tile 4 respects the supplied zone id, not the default system zone`() {
        // Same epoch millis can fall on a different local date in two zones
        // — pin that the parameter actually flows through.
        val instant = ZonedDateTime.of(2026, 5, 21, 1, 0, 0, 0, ZoneId.of("UTC"))
            .toInstant().toEpochMilli()
        // In Asia/Kolkata (+05:30), 2026-05-21T01:00Z is 2026-05-21T06:30 local.
        val ist = resolveScheduledSlot(4, today, pickedDateMillis = instant, zoneId = ZoneId.of("Asia/Kolkata"))
        assertEquals("2026-05-21", ist.first)
        // In America/Los_Angeles (-07:00 DST), it's 2026-05-20T18:00 local — yesterday.
        val pst = resolveScheduledSlot(4, today, pickedDateMillis = instant, zoneId = ZoneId.of("America/Los_Angeles"))
        assertEquals("2026-05-20", pst.first)
    }

    @Test fun `timestampedName drops everything before the last slash`() {
        val name = requestServiceTimestampedName("content://media/photo.jpg")
        assertTrue("expected -photo.jpg tail in $name", name.endsWith("-photo.jpg"))
    }

    @Test fun `timestampedName falls back to photo jpg for blank tail`() {
        val name = requestServiceTimestampedName("path/")
        assertTrue("expected -photo.jpg tail in $name", name.endsWith("-photo.jpg"))
    }

    @Test fun `timestampedName collapses unsafe chars`() {
        val name = requestServiceTimestampedName("issue photo (1).jpg")
        assertTrue("expected sanitized tail in $name", name.endsWith("-issue_photo__1_.jpg"))
    }
}
