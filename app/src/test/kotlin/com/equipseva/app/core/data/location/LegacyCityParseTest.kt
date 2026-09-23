package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The legacy `engineers.city` string ("Mandal, District, State") is the
 * only place many engineer rows keep their geography. PRODUCT_PLAN §6 wants
 * such values readable and flagged as needing confirmation when anything
 * is inferred or unplaceable — never silently mapped. These tests pin that
 * contract, including a full round trip over every bundled pair so the
 * parser can never disagree with [IndiaLocations.compose].
 */
class LegacyCityParseTest {

    @Test
    fun `blank input is empty, not unresolved`() {
        listOf(null, "", "   ", ",", " , ,").forEach { raw ->
            val parsed = parseLegacyCity(raw)
            assertEquals(LegacyCityParse.EMPTY, parsed)
            assertTrue(parsed.isEmpty)
            assertFalse(parsed.needsConfirmation)
            assertFalse(parsed.isComplete)
        }
    }

    @Test
    fun `explicit district and State resolve without confirmation`() {
        val parsed = parseLegacyCity("Hyderabad, Telangana")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertNull(parsed.mandal)
        assertTrue(parsed.isComplete)
        assertFalse(parsed.needsConfirmation)
        assertTrue(parsed.unresolved.isEmpty())
    }

    @Test
    fun `case and spacing do not matter`() {
        val parsed = parseLegacyCity(" hyderabad ,  telangana ")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertFalse(parsed.needsConfirmation)
    }

    @Test
    fun `mandal resolves when the district is known`() {
        val medak = parseLegacyCity("Medak, Medak, Telangana")
        assertEquals("Medak", medak.mandal)
        assertEquals("Medak", medak.district)
        val secunderabad = parseLegacyCity("Secunderabad, Hyderabad, Telangana")
        assertEquals("Secunderabad", secunderabad.mandal)
        assertFalse(secunderabad.needsConfirmation)
    }

    @Test
    fun `legacy spellings resolve through the alias tables`() {
        assertEquals("Bengaluru Urban", parseLegacyCity("Bangalore, Karnataka").district)
        assertEquals("Rangareddy", parseLegacyCity("Ranga Reddy, Telangana").district)
        assertEquals("Odisha", parseLegacyCity("Bhubaneswar, Orissa").state)
        assertEquals("Khordha", parseLegacyCity("Bhubaneswar, Orissa").district)
        assertEquals("Chhatrapati Sambhaji Nagar", parseLegacyCity("Aurangabad, Maharashtra").district)
        assertEquals("Aurangabad", parseLegacyCity("Aurangabad, Bihar").district)
    }

    @Test
    fun `a lone nationally unique district infers its State but needs confirmation`() {
        val parsed = parseLegacyCity("Hyderabad")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertTrue(parsed.isComplete)
        assertTrue(parsed.needsConfirmation)
        assertTrue(parsed.unresolved.isEmpty())
        assertTrue(parsed.stateCandidates.isEmpty())
    }

    @Test
    fun `a lone New Delhi is the district with the UT inferred, not the UT alone`() {
        val parsed = parseLegacyCity("New Delhi")
        assertEquals("Delhi", parsed.state)
        assertEquals("New Delhi", parsed.district)
        assertTrue(parsed.needsConfirmation)
    }

    @Test
    fun `an ambiguous lone district lists the candidate States and picks none`() {
        val parsed = parseLegacyCity("Bilaspur")
        assertNull(parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Chhattisgarh", "Himachal Pradesh"), parsed.stateCandidates)
        assertEquals(listOf("Bilaspur"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
        assertFalse(parsed.isComplete)
        assertFalse(parsed.isEmpty)
    }

    @Test
    fun `unknown text stays visible as unresolved`() {
        val parsed = parseLegacyCity("Atlantis")
        assertNull(parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Atlantis"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
        assertFalse(parsed.isEmpty)
    }

    @Test
    fun `an unknown district under a known State keeps the State and flags the district`() {
        val parsed = parseLegacyCity("Hyd, Telangana")
        assertEquals("Telangana", parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Hyd"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
        assertFalse(parsed.isComplete)
    }

    @Test
    fun `an unknown mandal or extra leading part is reported, not dropped`() {
        val unknownMandal = parseLegacyCity("Somewhere, Hyderabad, Telangana")
        assertEquals("Hyderabad", unknownMandal.district)
        assertNull(unknownMandal.mandal)
        assertEquals(listOf("Somewhere"), unknownMandal.unresolved)
        assertTrue(unknownMandal.needsConfirmation)

        val extra = parseLegacyCity("Extra, Medak, Medak, Telangana")
        assertEquals("Medak", extra.mandal)
        assertEquals(listOf("Extra"), extra.unresolved)
        assertTrue(extra.needsConfirmation)
    }

    @Test
    fun `a State alone is incomplete but not a confirmation problem`() {
        val parsed = parseLegacyCity("Telangana")
        assertEquals("Telangana", parsed.state)
        assertNull(parsed.district)
        assertFalse(parsed.isComplete)
        assertFalse(parsed.needsConfirmation)
    }

    @Test
    fun `every bundled State and district round-trips through compose`() {
        IndiaLocations.STATES.forEach { state ->
            IndiaLocations.districtsFor(state).forEach { district ->
                val parsed = parseLegacyCity(IndiaLocations.compose(state, district, null))
                assertEquals("state for $district, $state", state, parsed.state)
                assertEquals("district for $district, $state", district, parsed.district)
                assertNull(parsed.mandal)
                assertFalse("$district, $state should not need confirmation", parsed.needsConfirmation)
            }
        }
    }

    @Test
    fun `every bundled mandal round-trips through compose`() {
        var checked = 0
        IndiaLocations.STATES.forEach { state ->
            IndiaLocations.districtsFor(state).forEach { district ->
                IndiaLocations.mandalsFor(state, district).forEach { mandal ->
                    val parsed = parseLegacyCity(IndiaLocations.compose(state, district, mandal))
                    assertEquals(state, parsed.state)
                    assertEquals(district, parsed.district)
                    assertEquals("mandal for $mandal, $district, $state", mandal, parsed.mandal)
                    assertFalse(parsed.needsConfirmation)
                    checked++
                }
            }
        }
        assertTrue("expected the Telangana mandal lists to be exercised, got $checked", checked > 100)
    }
}
