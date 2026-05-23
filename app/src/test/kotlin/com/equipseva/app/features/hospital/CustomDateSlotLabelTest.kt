package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * Pins the custom date-slot label on the RequestService "When?" step.
 *
 * Critical regression target: Turkish-locale i-casing bug. Default
 * lowercase()/uppercase() on a Turkish-locale device renders "İ"
 * instead of "I", corrupting month names like JANUARY → "Ocak"
 * or "JAnuary" depending on which call was missing the Locale arg.
 */
class CustomDateSlotLabelTest {

    // ---- customDateSlotLabelForDate (pure) ---------------------------

    @Test fun `format is Custom middle-dot D Month YYYY`() {
        assertEquals(
            "Custom · 23 May 2026",
            customDateSlotLabelForDate(LocalDate.of(2026, 5, 23)),
        )
    }

    @Test fun `single-digit day renders without zero-padding`() {
        // Pin so a refactor to %02d (zero-pad) surfaces here.
        assertEquals(
            "Custom · 5 January 2026",
            customDateSlotLabelForDate(LocalDate.of(2026, 1, 5)),
        )
    }

    @Test fun `month is title-cased English even with Turkish default locale`() {
        // Critical regression target — Turkish-locale i-casing rules.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"))
            assertEquals(
                "Custom · 5 January 2026",
                customDateSlotLabelForDate(LocalDate.of(2026, 1, 5)),
            )
            // "I" in JANUARY → "i" via Turkish locale would otherwise
            // produce "january"; replaceFirstChar Turkish would produce
            // "İanuary". Pin BOTH Locale.ENGLISH args.
            assertEquals(
                "Custom · 1 July 2026",
                customDateSlotLabelForDate(LocalDate.of(2026, 7, 1)),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `month is title-cased English even with Hindi default locale`() {
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "Custom · 23 May 2026",
                customDateSlotLabelForDate(LocalDate.of(2026, 5, 23)),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `all months render with proper title-case English names`() {
        // Sweep all 12 months to lock the format.
        val expected = listOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        )
        for (m in 1..12) {
            assertEquals(
                "Custom · 15 ${expected[m - 1]} 2026",
                customDateSlotLabelForDate(LocalDate.of(2026, m, 15)),
            )
        }
    }

    @Test fun `middle dot is U+00B7 not bullet or ASCII period`() {
        val out = customDateSlotLabelForDate(LocalDate.of(2026, 1, 1))
        assertEquals(true, out.contains('·'))
        assertEquals(false, out.contains('•'))
    }

    // ---- customDateSlotLabelFromMillis (with zone) -------------------

    @Test fun `null millis falls back to Pick a date`() {
        assertEquals("Pick a date", customDateSlotLabelFromMillis(null))
    }

    @Test fun `non-null millis is interpreted in IST not device-default zone`() {
        // 2026-05-23T18:30:00Z = 2026-05-24 00:00 IST.
        // Pin that the IST zone shifts the day forward.
        val midnightIstMay24 = LocalDate.of(2026, 5, 23)
            .atStartOfDay(ZoneId.of("Asia/Kolkata"))
            .plusHours(24)
            .toInstant()
            .toEpochMilli()
        assertEquals(
            "Custom · 24 May 2026",
            customDateSlotLabelFromMillis(midnightIstMay24),
        )
    }

    @Test fun `epoch zero is interpreted in IST (5h 30m after Unix epoch)`() {
        // Sanity check — pin the IST shift.
        assertEquals(
            "Custom · 1 January 1970",
            customDateSlotLabelFromMillis(0L),
        )
    }
}
