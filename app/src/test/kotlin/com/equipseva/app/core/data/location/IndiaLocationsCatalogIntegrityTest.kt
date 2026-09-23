package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the measured shape of the bundled catalog so the header comment of
 * [IndiaLocations] cannot drift from reality again. Its previous header said
 * coverage was "intentionally narrow" (Telangana plus a sample) while the
 * lists in the same file covered every State/UT — the exact contradiction
 * PRODUCT_PLAN §6 / delivery-ledger P2.2 asked to reconcile. Every claim the
 * new header makes is asserted here instead of merely restated.
 */
class IndiaLocationsCatalogIntegrityTest {

    @Test
    fun `every State or UT has at least one bundled district`() {
        val empty = IndiaLocations.STATES.filter { IndiaLocations.districtsFor(it).isEmpty() }
        assertTrue("States/UTs without districts: $empty", empty.isEmpty())
    }

    @Test
    fun `STATES lists 36 unique non-blank canonical names`() {
        assertEquals(36, IndiaLocations.STATES.size)
        assertEquals(36, IndiaLocations.STATES.toSet().size)
        assertTrue(IndiaLocations.STATES.none { it.isBlank() || it != it.trim() })
    }

    @Test
    fun `district lists carry no blanks or duplicates within a State or UT`() {
        IndiaLocations.STATES.forEach { state ->
            val districts = IndiaLocations.districtsFor(state)
            assertTrue("$state has a blank district", districts.none { it.isBlank() || it != it.trim() })
            val dupes = districts.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
            assertTrue("$state repeats districts: $dupes", dupes.isEmpty())
            // Two spellings of one district in the same list would make
            // canonicalDistrict pick whichever comes first — a data bug.
            val nearDupes = districts.groupingBy { IndiaRegionAliases.normalize(it) }
                .eachCount().filterValues { it > 1 }.keys
            assertTrue("$state has near-duplicate districts: $nearDupes", nearDupes.isEmpty())
        }
    }

    @Test
    fun `catalog extremes match the documented measurement`() {
        assertEquals(1, IndiaLocations.districtsFor("Chandigarh").size)
        assertEquals(1, IndiaLocations.districtsFor("Lakshadweep").size)
        assertEquals(75, IndiaLocations.districtsFor("Uttar Pradesh").size)
        val total = IndiaLocations.STATES.sumOf { IndiaLocations.districtsFor(it).size }
        assertTrue("expected the full national list, got $total districts", total >= 700)
    }

    @Test
    fun `mandals are bundled for exactly 14 Telangana districts and each is reachable from the picker`() {
        // Enumerate through districtsFor so a mandal list keyed by a district
        // spelling that is not in the Telangana list (unreachable from the
        // State -> District -> Mandal cascade) shows up as a shortfall.
        val withMandals = IndiaLocations.STATES.flatMap { state ->
            IndiaLocations.districtsFor(state)
                .filter { district -> IndiaLocations.mandalsFor(state, district).isNotEmpty() }
                .map { district -> state to district }
        }
        assertEquals("districts with reachable mandal lists: $withMandals", 14, withMandals.size)
        assertTrue(withMandals.all { it.first == "Telangana" })
    }

    @Test
    fun `CATALOG_VERSION is the pinned snapshot id`() {
        assertEquals("bundled-names-v1", IndiaLocations.CATALOG_VERSION)
    }

    @Test
    fun `KNOWN_MISSING districts are really absent from the bundled lists`() {
        assertTrue(IndiaLocations.KNOWN_MISSING.isNotEmpty())
        IndiaLocations.KNOWN_MISSING.forEach { (state, names) ->
            assertTrue("KNOWN_MISSING names an unknown State: $state", state in IndiaLocations.STATES)
            val bundled = IndiaLocations.districtsFor(state).map { IndiaRegionAliases.normalize(it) }.toSet()
            names.forEach { name ->
                assertTrue(
                    "$name is now bundled for $state — remove it from KNOWN_MISSING and update the header",
                    IndiaRegionAliases.normalize(name) !in bundled,
                )
            }
        }
    }

    @Test
    fun `district names shared across States include the known ambiguous set`() {
        val homes = mutableMapOf<String, MutableList<String>>()
        IndiaLocations.STATES.forEach { state ->
            IndiaLocations.districtsFor(state).forEach { district ->
                homes.getOrPut(district) { mutableListOf() } += state
            }
        }
        val shared = homes.filterValues { it.size > 1 }
        listOf("Bilaspur", "Hamirpur", "Pratapgarh", "Balrampur").forEach {
            assertTrue("$it should exist in more than one State", it in shared)
        }
        // Alphabetical STATES order is what parseLegacyCity reports as candidates.
        assertEquals(listOf("Chhattisgarh", "Himachal Pradesh"), shared.getValue("Bilaspur"))
    }
}
