package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Pins the request-service slot-picker resolver. Five tiles + a
 * negative-index unselected case. Two regions worth defending:
 *
 *   1) Tile copy → date offset map: 0=today/evening, 1=tomorrow/
 *      morning, 2=tomorrow/afternoon. A regression that swapped
 *      morning/afternoon would mis-schedule every booking by half
 *      a day on the engineer's calendar.
 *   2) The custom-date tile (4) anchors the picked instant to IST
 *      before extracting LocalDate. Without this, a device on UTC
 *      picking "May 21" at 11:30 PM IST would persist "May 20" —
 *      the engineer would arrive a day early. Pin so the IST
 *      anchoring stays explicit.
 */
class ResolveScheduledSlotTest {

    private val today = LocalDate.of(2026, 5, 21)

    @Test fun `slot 0 yields today evening`() {
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 0,
            today = today,
            pickedDateMillis = null,
        )
        assertEquals("2026-05-21", date)
        assertEquals("evening", slot)
    }

    @Test fun `slot 1 yields tomorrow morning`() {
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 1,
            today = today,
            pickedDateMillis = null,
        )
        assertEquals("2026-05-22", date)
        assertEquals("morning", slot)
    }

    @Test fun `slot 2 yields tomorrow afternoon`() {
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 2,
            today = today,
            pickedDateMillis = null,
        )
        assertEquals("2026-05-22", date)
        assertEquals("afternoon", slot)
    }

    @Test fun `slot 3 (flexible) yields null date with flexible slot`() {
        // The "any time" preference is recorded explicitly — pin so
        // a future refactor doesn't collapse it back to (null, null)
        // and lose the user's intent.
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 3,
            today = today,
            pickedDateMillis = null,
        )
        assertNull(date)
        assertEquals("flexible", slot)
    }

    @Test fun `slot 4 with picked date yields that date with any slot`() {
        // 2026-05-25 00:00 IST = 2026-05-24 18:30 UTC. Use a
        // ZonedDateTime to construct the millis deterministically.
        val ist = ZoneId.of("Asia/Kolkata")
        val pickedInst = ZonedDateTime.of(LocalDate.of(2026, 5, 25).atTime(0, 0), ist).toInstant()
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 4,
            today = today,
            pickedDateMillis = pickedInst.toEpochMilli(),
        )
        assertEquals("2026-05-25", date)
        assertEquals("any", slot)
    }

    @Test fun `slot 4 anchors the picked instant to IST (not device-local zone)`() {
        // 2026-05-21 23:30 IST = 2026-05-21 18:00 UTC. The picker
        // hands back the user-picked midnight in IST — pin that the
        // resolver does NOT shift the date based on the device's
        // current zone.
        val ist = ZoneId.of("Asia/Kolkata")
        val pickedInst = ZonedDateTime.of(
            LocalDate.of(2026, 5, 21).atTime(23, 30), ist,
        ).toInstant()
        val (date, _) = resolveScheduledSlot(
            selectedSlot = 4,
            today = today,
            pickedDateMillis = pickedInst.toEpochMilli(),
        )
        assertEquals("2026-05-21", date)
    }

    @Test fun `slot 4 with null pickedDateMillis falls back to no selection`() {
        // User tapped the calendar tile but didn't pick a date — the
        // form treats this as no selection (same as unpicked).
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 4,
            today = today,
            pickedDateMillis = null,
        )
        assertNull(date)
        assertNull(slot)
    }

    @Test fun `negative selectedSlot yields null date and null slot`() {
        // Default value when no tile is picked.
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = -1,
            today = today,
            pickedDateMillis = null,
        )
        assertNull(date)
        assertNull(slot)
    }

    @Test fun `out-of-range selectedSlot yields null pair (forward-compat)`() {
        // A future tile addition without updating the resolver shouldn't
        // crash — fall through to no selection.
        val (date, slot) = resolveScheduledSlot(
            selectedSlot = 99,
            today = today,
            pickedDateMillis = null,
        )
        assertNull(date)
        assertNull(slot)
    }

    @Test fun `today plus one day rolls month boundary cleanly`() {
        // Last day of May → June 1. Defensive: pin so manual
        // arithmetic (e.g. day + 1 without LocalDate) wouldn't slip in.
        val lastDayOfMay = LocalDate.of(2026, 5, 31)
        val (date, _) = resolveScheduledSlot(
            selectedSlot = 1,
            today = lastDayOfMay,
            pickedDateMillis = null,
        )
        assertEquals("2026-06-01", date)
    }
}
