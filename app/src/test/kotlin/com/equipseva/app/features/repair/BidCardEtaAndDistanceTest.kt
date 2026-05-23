package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class BidCardEtaAndDistanceTest {

    // ---- bidCardEtaText ----------------------------------------------

    @Test fun `eta value reads ETA colon Nh`() {
        assertEquals("ETA: 4h", bidCardEtaText(4))
    }

    @Test fun `null eta reads ETA colon em-dash`() {
        // Critical pin — em-dash explicit "no ETA given" signal.
        // A refactor to "TBD" / "Not given" would inflate row width.
        assertEquals("ETA: —", bidCardEtaText(null))
    }

    @Test fun `colon-space form preserved (NOT bare ETA)`() {
        // Pin "ETA: Nh" colon-form — distinguishes bid-list compact
        // row from own-bid hero card which uses "ETA Nh" no colon.
        val out = bidCardEtaText(4)
        assertTrue(out.startsWith("ETA: "))
    }

    @Test fun `em-dash is U+2014 not en-dash`() {
        val out = bidCardEtaText(null)
        assertTrue(out.contains('—'))
        assertEquals(false, out.contains('–'))
    }

    @Test fun `large eta interpolates verbatim`() {
        assertEquals("ETA: 720h", bidCardEtaText(720))
    }

    // ---- bidCardDistanceLabel ----------------------------------------

    @Test fun `non-null distance returns formatted label with middle-dot prefix`() {
        assertEquals(
            "· 3.2 km away",
            bidCardDistanceLabel(3.2),
        )
    }

    @Test fun `null distance returns null (caller hides chip)`() {
        assertNull(bidCardDistanceLabel(null))
    }

    @Test fun `Locale-US stable across hi-IN and German`() {
        // Pin — comma-decimal locales would render "3,2 km away".
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "· 3.2 km away",
                bidCardDistanceLabel(3.2),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "· 3.2 km away",
                bidCardDistanceLabel(3.2),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `whole-km distance still shows one decimal`() {
        assertEquals(
            "· 5.0 km away",
            bidCardDistanceLabel(5.0),
        )
    }

    @Test fun `km away suffix is mandatory (disambiguates from radius)`() {
        // Pin "km away" not bare "km" — the engineer's listed service
        // radius elsewhere is also in km; "away" anchors this as
        // distance-from-job.
        val out = bidCardDistanceLabel(1.0)
        assertTrue(out!!.endsWith(" km away"))
    }

    @Test fun `middle dot leading separator is U+00B7`() {
        val out = bidCardDistanceLabel(1.0)
        assertTrue(out!!.startsWith("· "))
    }
}
