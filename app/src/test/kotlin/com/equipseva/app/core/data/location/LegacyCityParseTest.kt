package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Legacy free-text location strings (`engineers.city` as written by the KYC
 * flow — a bare district, or a "My location" address ending in "…, state,
 * pincode" — plus the older "District, State" / "Mandal, District, State"
 * shapes) must stay readable and be flagged as needing confirmation when
 * anything is inferred, ambiguous or unplaceable — never silently mapped.
 * These tests pin that contract, including a round trip over every bundled
 * pair so the parser can never disagree with [IndiaLocations.compose].
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
    fun `blank input with a known State column yields that State only`() {
        val parsed = parseLegacyCity("", knownState = "Telangana")
        assertEquals("Telangana", parsed.state)
        assertNull(parsed.district)
        assertFalse(parsed.isEmpty)
        assertFalse(parsed.needsConfirmation)
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
    fun `a My-location address with pincode tail resolves State and district and keeps the remnants`() {
        val parsed = parseLegacyCity("12 MG Road, Banjara Hills, Hyderabad, Hyderabad, Telangana, 500034")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertNull(parsed.mandal)
        assertEquals(listOf("12 MG Road", "Banjara Hills", "Hyderabad", "500034"), parsed.unresolved)
        assertTrue(parsed.isComplete)
        assertFalse(parsed.needsConfirmation)
    }

    @Test
    fun `Geocoder district labels in the district slot resolve to the real district, not an earlier locality`() {
        // Google labels Rangareddy "K.V.Rangareddy"; the locality token before it
        // is "Hyderabad", which is also a district name. The slot must win.
        val kvr = parseLegacyCity("Plot 5, Gachibowli, Hyderabad, K.V.Rangareddy, Telangana, 500032", knownState = "Telangana")
        assertEquals("Rangareddy", kvr.district)
        assertEquals("Telangana", kvr.state)
        assertFalse(kvr.needsConfirmation)
        assertEquals(listOf("Plot 5", "Gachibowli", "Hyderabad", "500032"), kvr.unresolved)

        val malkajgiri = parseLegacyCity("Kukatpally, Hyderabad, Malkajgiri, Telangana, 500072")
        assertEquals("Medchal-Malkajgiri", malkajgiri.district)
        assertFalse(malkajgiri.needsConfirmation)

        val labelled = parseLegacyCity("Gachibowli, Hyderabad, Rangareddy District, Telangana, 500032")
        assertEquals("Rangareddy", labelled.district)
        assertFalse(labelled.needsConfirmation)
    }

    @Test
    fun `an unreadable token in the district slot makes an earlier district match a suggestion only`() {
        val withState = parseLegacyCity("Gachibowli, Hyderabad, Shamshabad Zone, Telangana, 500409")
        assertEquals("Telangana", withState.state)
        assertEquals("Hyderabad", withState.district)
        assertTrue(withState.needsConfirmation)
        assertEquals(listOf("Gachibowli", "Shamshabad Zone", "500409"), withState.unresolved)

        // Same with the State only in the column: the pincode is a known remnant,
        // the unknown label before it is not.
        val withColumn = parseLegacyCity("Kukatpally, Hyderabad, Foo Bar, 500072", knownState = "Telangana")
        assertEquals("Hyderabad", withColumn.district)
        assertTrue(withColumn.needsConfirmation)
        assertEquals(listOf("Kukatpally", "Foo Bar", "500072"), withColumn.unresolved)
    }

    @Test
    fun `known remnants are a six-digit pincode or the country`() {
        assertTrue(LegacyCityParse.isKnownRemnant("500034"))
        assertTrue(LegacyCityParse.isKnownRemnant("500 034"))
        assertTrue(LegacyCityParse.isKnownRemnant(" India "))
        assertTrue(LegacyCityParse.isKnownRemnant("Bharat"))
        assertFalse(LegacyCityParse.isKnownRemnant("Gachibowli"))
        assertFalse(LegacyCityParse.isKnownRemnant("50003"))
        assertFalse(LegacyCityParse.isKnownRemnant("5000340"))
    }

    @Test
    fun `an unreadable token after the State token also makes the district a suggestion`() {
        val parsed = parseLegacyCity("Hyderabad, Telangana, Rangareddy Zone")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertTrue(parsed.needsConfirmation)
        assertEquals(listOf("Rangareddy Zone"), parsed.unresolved)
        // Known remnants after the State do not.
        assertFalse(parseLegacyCity("Hyderabad, Telangana, 500 034, India").needsConfirmation)
    }

    @Test
    fun `explicit text with an unresolvable State column still asks`() {
        val parsed = parseLegacyCity("Hyderabad, Telangana", knownState = "Atlantis")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertEquals(listOf("Atlantis"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
    }

    @Test
    fun `stateInferred distinguishes a worked-out State from a stated one`() {
        assertTrue(parseLegacyCity("Hyderabad").stateInferred)
        assertFalse(parseLegacyCity("Hyderabad, Telangana").stateInferred)
        assertFalse(parseLegacyCity("Hyderabad", knownState = "Telangana").stateInferred)
        assertFalse(parseLegacyCity("Bilaspur").stateInferred)
    }

    @Test
    fun `an unresolvable State column stays visible and asks`() {
        val blank = parseLegacyCity("", knownState = "Atlantis")
        assertNull(blank.state)
        assertEquals(listOf("Atlantis"), blank.unresolved)
        assertTrue(blank.needsConfirmation)
        assertFalse(blank.isEmpty)

        // "New Delhi" is a district, not a State, so the column is unusable;
        // the lone district still infers its State and everything is flagged.
        val lone = parseLegacyCity("Hyderabad", knownState = "New Delhi")
        assertEquals("Telangana", lone.state)
        assertEquals("Hyderabad", lone.district)
        assertEquals(listOf("New Delhi"), lone.unresolved)
        assertTrue(lone.needsConfirmation)
    }

    @Test
    fun `an India tail is a remnant, not a failure`() {
        val parsed = parseLegacyCity("Hyderabad, Telangana, India")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertEquals(listOf("India"), parsed.unresolved)
        assertFalse(parsed.needsConfirmation)
    }

    @Test
    fun `a bare district with the State column resolves without confirmation`() {
        val parsed = parseLegacyCity("Rangareddy", knownState = "Telangana")
        assertEquals("Telangana", parsed.state)
        assertEquals("Rangareddy", parsed.district)
        assertFalse(parsed.needsConfirmation)
        val withPincode = parseLegacyCity("Hyderabad, 500034", knownState = "Telangana")
        assertEquals("Hyderabad", withPincode.district)
        assertEquals(listOf("500034"), withPincode.unresolved)
        assertFalse(withPincode.needsConfirmation)
    }

    @Test
    fun `text and State column disagreeing keeps the text reading and asks`() {
        val parsed = parseLegacyCity("Hyderabad, Telangana", knownState = "Karnataka")
        assertEquals("Telangana", parsed.state)
        assertEquals("Hyderabad", parsed.district)
        assertEquals(listOf("Telangana", "Karnataka"), parsed.stateCandidates)
        assertTrue(parsed.needsConfirmation)
    }

    @Test
    fun `a district that does not belong to the State column is not guessed into another State`() {
        val parsed = parseLegacyCity("Hyderabad", knownState = "Karnataka")
        assertEquals("Karnataka", parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Hyderabad"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
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
        val bilaspur = parseLegacyCity("Bilaspur")
        assertNull(bilaspur.state)
        assertNull(bilaspur.district)
        assertEquals(listOf("Chhattisgarh", "Himachal Pradesh"), bilaspur.stateCandidates)
        assertEquals(listOf("Bilaspur"), bilaspur.unresolved)
        assertTrue(bilaspur.needsConfirmation)
        assertFalse(bilaspur.isComplete)
        assertFalse(bilaspur.isEmpty)
        // Alias-driven ambiguity counts too: Maharashtra's renamed district and
        // Karnataka's Vijayapura still answer to their old names.
        assertEquals(listOf("Bihar", "Maharashtra"), parseLegacyCity("Aurangabad").stateCandidates)
        assertEquals(listOf("Chhattisgarh", "Karnataka"), parseLegacyCity("Bijapur").stateCandidates)
    }

    @Test
    fun `a lone city that is deliberately not aliased stays unresolved with no candidates`() {
        val parsed = parseLegacyCity("Mumbai")
        assertNull(parsed.state)
        assertNull(parsed.district)
        assertTrue(parsed.stateCandidates.isEmpty())
        assertEquals(listOf("Mumbai"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
        // Secunderabad straddles two districts, so it is not an alias; under
        // its State it stays visible and asks, rather than becoming Hyderabad.
        val secunderabad = parseLegacyCity("Secunderabad, Telangana")
        assertEquals("Telangana", secunderabad.state)
        assertNull(secunderabad.district)
        assertEquals(listOf("Secunderabad"), secunderabad.unresolved)
        assertTrue(secunderabad.needsConfirmation)
    }

    @Test
    fun `the retired UT name reads as the live district with its merged UT inferred`() {
        val parsed = parseLegacyCity("Dadra and Nagar Haveli")
        assertEquals("Dadra and Nagar Haveli and Daman and Diu", parsed.state)
        assertEquals("Dadra and Nagar Haveli", parsed.district)
        assertTrue(parsed.needsConfirmation)
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
    fun `a pre-2014 row naming Hyderabad under Andhra Pradesh is not silently moved`() {
        val parsed = parseLegacyCity("Hyderabad, Andhra Pradesh")
        assertEquals("Andhra Pradesh", parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Hyderabad"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
    }

    @Test
    fun `a reversed State-first string yields the State and flags the rest`() {
        val parsed = parseLegacyCity("Telangana, Hyderabad")
        assertEquals("Telangana", parsed.state)
        assertNull(parsed.district)
        assertEquals(listOf("Hyderabad"), parsed.unresolved)
        assertTrue(parsed.needsConfirmation)
    }

    @Test
    fun `remnants beside a resolved district are reported but do not require confirmation`() {
        val unknownMandal = parseLegacyCity("Somewhere, Hyderabad, Telangana")
        assertEquals("Hyderabad", unknownMandal.district)
        assertNull(unknownMandal.mandal)
        assertEquals(listOf("Somewhere"), unknownMandal.unresolved)
        assertFalse(unknownMandal.needsConfirmation)

        val extra = parseLegacyCity("Extra, Medak, Medak, Telangana")
        assertEquals("Medak", extra.mandal)
        assertEquals(listOf("Extra"), extra.unresolved)
        assertFalse(extra.needsConfirmation)
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
                assertTrue(parsed.unresolved.isEmpty())
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
                    assertTrue(parsed.unresolved.isEmpty())
                    assertFalse(parsed.needsConfirmation)
                    checked++
                }
            }
        }
        assertTrue("expected the Telangana mandal lists to be exercised, got $checked", checked > 100)
    }
}
