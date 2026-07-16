package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1425 engineer Code Red helpers. */
class EngineerCodeRedHelpersTest {

    @Test fun `equipment title joins type, brand, model`() {
        assertEquals("Ventilator · Philips V60", codeRedEquipmentTitle("Ventilator", "Philips", "V60"))
        assertEquals("Ventilator · Philips", codeRedEquipmentTitle("Ventilator", "Philips", null))
        assertEquals("Ventilator", codeRedEquipmentTitle("Ventilator", null, "  "))
    }

    @Test fun `equipment title never blank`() {
        assertEquals("Equipment", codeRedEquipmentTitle("", null, null))
    }

    @Test fun `distance drops redundant decimal and adds km`() {
        assertEquals("4 km", formatDistanceKm(4.0))
        assertEquals("4.2 km", formatDistanceKm(4.2))
    }
}
