package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class SpotAuditsSubtitleTest {

    @Test fun `non-empty with rating renders count + avg slash 5`() {
        assertEquals(
            "5 in last 30 days · avg 4.8/5",
            spotAuditsSubtitle(rowCount = 5, avgRating = 4.8),
        )
    }

    @Test fun `null avgRating falls back to em-dash slash 5`() {
        // Critical pin — "—/5" communicates "no data yet". A refactor
        // that surfaced "0.0/5" would read as "everyone hates us".
        assertEquals(
            "5 in last 30 days · avg —/5",
            spotAuditsSubtitle(rowCount = 5, avgRating = null),
        )
    }

    @Test fun `0 rows returns null regardless of rating`() {
        assertNull(spotAuditsSubtitle(0, 4.8))
        assertNull(spotAuditsSubtitle(0, null))
    }

    @Test fun `rating formatter is Locale-US stable not device-locale`() {
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "5 in last 30 days · avg 4.8/5",
                spotAuditsSubtitle(5, 4.8),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "5 in last 30 days · avg 4.8/5",
                spotAuditsSubtitle(5, 4.8),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `slash 5 denominator is mandatory (scale anchor)`() {
        // Pin /5 — the rating scale is 1–5. Without it, "avg 4.8"
        // is ambiguous (out of 5? 10? 100?).
        val out = spotAuditsSubtitle(1, 4.8)
        assertTrue(out!!.endsWith("/5"))
    }

    @Test fun `em-dash fallback is U+2014 not en-dash`() {
        val out = spotAuditsSubtitle(1, null)
        assertTrue(out!!.contains('—'))
        assertEquals(false, out.contains('–'))
    }

    @Test fun `whole-number rating still shows one decimal`() {
        // Pin %.1f — "5.0/5" not "5/5".
        assertEquals(
            "1 in last 30 days · avg 5.0/5",
            spotAuditsSubtitle(1, 5.0),
        )
    }

    @Test fun `30 days literal is preserved verbatim`() {
        // Pin — distinct from 365d cash-flag window and 12-month
        // disputes window.
        val out = spotAuditsSubtitle(1, 4.0)
        assertTrue(out!!.contains("last 30 days"))
    }
}
