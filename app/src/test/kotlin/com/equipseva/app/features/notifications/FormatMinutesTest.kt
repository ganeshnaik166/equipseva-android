package com.equipseva.app.features.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the quiet-hours minute → HH:mm/h:mm AM-PM rendering. Three
 * regions that have bitten us:
 *
 *   1) ASCII digits on Hindi locale — `%d` produces Devanagari
 *      numerals when the JVM default locale is Hindi; the production
 *      code pins `Locale.US`. A regression that dropped the locale
 *      would surface as ौ२:०० on Indian devices.
 *   2) 24-hour clock wrap — `1440 % (24*60)` should yield 00:00, not
 *      24:00; negative inputs should wrap modulo a day. Caught here
 *      so a refactor doesn't silently start spitting "26:30".
 *   3) 12-hour AM/PM edge cases — midnight is 12 AM, noon is 12 PM,
 *      anything past noon subtracts 12. Pinning so the picker readout
 *      stays consistent with the OS picker dialog.
 */
class FormatMinutesTest {

    @Test fun `midnight 24h renders 00 colon 00`() {
        assertEquals("00:00", formatMinutes(0))
    }

    @Test fun `noon 24h renders 12 colon 00`() {
        assertEquals("12:00", formatMinutes(12 * 60))
    }

    @Test fun `arbitrary time 24h zero-pads single digits`() {
        assertEquals("06:05", formatMinutes(6 * 60 + 5))
        assertEquals("23:59", formatMinutes(23 * 60 + 59))
    }

    @Test fun `negative minute wraps modulo a day`() {
        // -30 → 23:30 (one minute before yesterday's midnight,
        // viewed today)
        assertEquals("23:30", formatMinutes(-30))
    }

    @Test fun `minute equal to one day rolls over to 00 colon 00`() {
        assertEquals("00:00", formatMinutes(24 * 60))
    }

    @Test fun `multi-day minute wraps cleanly`() {
        // 49 hours → 1 day + 1 hour = 01:00
        assertEquals("01:00", formatMinutes(49 * 60))
    }

    // ---- 12-hour AM/PM ----

    @Test fun `12h midnight is 12 AM`() {
        assertEquals("12:00 AM", formatMinutes(0, is24Hour = false))
    }

    @Test fun `12h noon is 12 PM`() {
        assertEquals("12:00 PM", formatMinutes(12 * 60, is24Hour = false))
    }

    @Test fun `12h morning shows hour without zero-pad`() {
        // The 24h variant pads to "06:30"; the 12h variant doesn't —
        // matches the OS picker readout.
        assertEquals("6:30 AM", formatMinutes(6 * 60 + 30, is24Hour = false))
    }

    @Test fun `12h afternoon subtracts 12 from the hour`() {
        assertEquals("9:00 PM", formatMinutes(21 * 60, is24Hour = false))
        assertEquals("1:00 PM", formatMinutes(13 * 60, is24Hour = false))
    }

    @Test fun `12h minute zero-pads even when hour does not`() {
        assertEquals("3:05 AM", formatMinutes(3 * 60 + 5, is24Hour = false))
    }
}
