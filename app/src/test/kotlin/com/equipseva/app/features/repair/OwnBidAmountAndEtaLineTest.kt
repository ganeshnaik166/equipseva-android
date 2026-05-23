package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OwnBidAmountAndEtaLineTest {

    @Test fun `amount with eta renders amount middle-dot ETA Nh`() {
        val out = ownBidAmountAndEtaLine(2500.0, 4)
        assertTrue(out.contains("₹2,500"))
        assertTrue(out.endsWith(" · ETA 4h"))
    }

    @Test fun `null eta drops the suffix entirely (no trailing separator)`() {
        // Critical pin — null etaHours must NOT leave a naked
        // trailing " · ETA " or dot.
        val out = ownBidAmountAndEtaLine(2500.0, null)
        assertTrue(out.contains("₹2,500"))
        assertEquals(false, out.endsWith("·"))
        assertEquals(false, out.endsWith(" "))
        assertEquals(false, out.contains("ETA"))
    }

    @Test fun `ETA Nh compact form preserved (no space between N and h)`() {
        // Pin "ETA 4h" not "ETA 4 hours" — matches bid-list card.
        val out = ownBidAmountAndEtaLine(1.0, 4)
        assertTrue(out.contains("ETA 4h"))
        assertEquals(false, out.contains("ETA 4 h"))
        assertEquals(false, out.contains("ETA 4 hours"))
    }

    @Test fun `middle dot is U+00B7`() {
        val out = ownBidAmountAndEtaLine(1.0, 1)
        assertTrue(out.contains(" · "))
    }

    @Test fun `large eta interpolates verbatim`() {
        val out = ownBidAmountAndEtaLine(1.0, 720)
        assertTrue(out.endsWith("ETA 720h"))
    }
}
