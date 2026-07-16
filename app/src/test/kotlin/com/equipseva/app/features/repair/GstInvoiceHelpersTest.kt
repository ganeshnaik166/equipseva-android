package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1412 GST invoice helpers. */
class GstInvoiceHelpersTest {

    @Test fun `address line joins present parts`() {
        assertEquals(
            "12 MG Road, Hyderabad, Telangana, 500001",
            invoiceAddressLine("12 MG Road", "Hyderabad", "Telangana", "500001"),
        )
    }

    @Test fun `address line omits blanks and nulls`() {
        assertEquals("Hyderabad, Telangana", invoiceAddressLine(null, "Hyderabad", "Telangana", "  "))
        assertEquals("", invoiceAddressLine(null, null, null, null))
    }

    @Test fun `equipment line joins type brand model`() {
        assertEquals("Ventilator · Philips · V60", equipmentLine("Ventilator", "Philips", "V60"))
        assertEquals("Ventilator", equipmentLine("Ventilator", null, "  "))
    }
}
