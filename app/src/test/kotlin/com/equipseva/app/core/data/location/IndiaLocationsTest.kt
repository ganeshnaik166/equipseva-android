package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the IndiaLocations cascade contract. Two regions to defend:
 *
 *   1) The state list covers all 28 states + 8 UTs and Telangana (our
 *      active market) is present — the rest of the UI assumes it is.
 *   2) The cascade gracefully degrades: an unknown state yields an
 *      empty district list; blank inputs to mandalsFor yield empty
 *      (no NPE). The composer drops blank parts so a partial
 *      selection still produces a non-mangled "city" string for
 *      engineers.city storage.
 */
class IndiaLocationsTest {

    @Test fun `STATES contains 28 states plus 8 union territories`() {
        // 36 total — pin so a future deletion / typo is intentional.
        assertEquals(36, IndiaLocations.STATES.size)
    }

    @Test fun `STATES contains Telangana (active market) and Karnataka`() {
        assertTrue(IndiaLocations.STATES.contains("Telangana"))
        assertTrue(IndiaLocations.STATES.contains("Karnataka"))
    }

    @Test fun `country is fixed to India`() {
        assertEquals("India", IndiaLocations.COUNTRY)
    }

    @Test fun `districtsFor Telangana returns a non-empty list (active market)`() {
        val districts = IndiaLocations.districtsFor("Telangana")
        assertTrue("expected at least one Telangana district", districts.isNotEmpty())
        // The KYC happy path uses Hyderabad.
        assertTrue(districts.contains("Hyderabad"))
    }

    @Test fun `districtsFor null or unknown state yields empty list`() {
        // The UI falls back to free-text District input on empty —
        // returning emptyList() rather than throwing keeps the form
        // editable in unsupported regions.
        assertTrue(IndiaLocations.districtsFor(null).isEmpty())
        assertTrue(IndiaLocations.districtsFor("").isEmpty())
        assertTrue(IndiaLocations.districtsFor("Atlantis").isEmpty())
    }

    @Test fun `mandalsFor Telangana Medak returns the curated list`() {
        val mandals = IndiaLocations.mandalsFor("Telangana", "Medak")
        assertTrue(mandals.isNotEmpty())
        assertTrue(mandals.contains("Medak"))
    }

    @Test fun `mandalsFor null state or district yields empty list`() {
        assertTrue(IndiaLocations.mandalsFor(null, "Medak").isEmpty())
        assertTrue(IndiaLocations.mandalsFor("Telangana", null).isEmpty())
        assertTrue(IndiaLocations.mandalsFor(null, null).isEmpty())
    }

    @Test fun `mandalsFor blank inputs yields empty list (defensive)`() {
        assertTrue(IndiaLocations.mandalsFor("  ", "Medak").isEmpty())
        assertTrue(IndiaLocations.mandalsFor("Telangana", "  ").isEmpty())
    }

    @Test fun `mandalsFor unknown district yields empty list`() {
        assertTrue(IndiaLocations.mandalsFor("Telangana", "Unknownsdistrict").isEmpty())
    }

    @Test fun `compose joins mandal district state with comma`() {
        assertEquals(
            "Medak, Medak, Telangana",
            IndiaLocations.compose("Telangana", "Medak", "Medak"),
        )
    }

    @Test fun `compose drops blank or null parts`() {
        assertEquals(
            "Hyderabad, Telangana",
            IndiaLocations.compose("Telangana", "Hyderabad", null),
        )
        assertEquals(
            "Telangana",
            IndiaLocations.compose("Telangana", null, null),
        )
        assertEquals(
            "Hyderabad, Telangana",
            IndiaLocations.compose("Telangana", "Hyderabad", "  "),
        )
    }

    @Test fun `compose of all-null returns empty string`() {
        assertEquals("", IndiaLocations.compose(null, null, null))
    }
}
