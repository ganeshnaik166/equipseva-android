package com.equipseva.app.features.catalog

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1410 equipment-catalog browse helpers. */
class CatalogBrowseHelpersTest {

    @Test fun `category key de-snakes and blank stays blank`() {
        assertEquals("Patient monitor", categoryKeyLabel("patient_monitor"))
        assertEquals("Ventilator", categoryKeyLabel("ventilator"))
        assertEquals("", categoryKeyLabel(null))
        assertEquals("", categoryKeyLabel("  "))
    }

    @Test fun `subtitle joins present parts with a middot`() {
        assertEquals(
            "GE · GE Healthcare · Patient monitor",
            deviceSubtitle("GE", "GE Healthcare", "patient_monitor"),
        )
    }

    @Test fun `subtitle omits blank and null parts`() {
        assertEquals("Philips", deviceSubtitle("Philips", null, null))
        assertEquals("Ventilator", deviceSubtitle(null, "  ", "ventilator"))
        assertEquals("", deviceSubtitle(null, null, null))
    }
}
