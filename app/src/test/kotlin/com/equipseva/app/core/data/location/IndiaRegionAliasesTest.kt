package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Alias tables are data, so this test does what a reviewer cannot do by eye:
 * it proves every alias points at a name that really exists in the catalog,
 * is stored in normalized form, and never shadows a live name. Then it pins
 * the resolution behaviour callers rely on — including the negative cases
 * (no substring guessing, State/UT-scoped district history).
 */
class IndiaRegionAliasesTest {

    @Test
    fun `normalize folds case, ampersand, dashes, punctuation and spacing`() {
        assertEquals("jammu and kashmir", IndiaRegionAliases.normalize("Jammu & Kashmir"))
        assertEquals("medchal malkajgiri", IndiaRegionAliases.normalize(" Medchal–Malkajgiri "))
        assertEquals("medchal malkajgiri", IndiaRegionAliases.normalize("Medchal-Malkajgiri"))
        assertEquals("y s r kadapa", IndiaRegionAliases.normalize("Y.S.R. Kadapa"))
        assertEquals("tamil nadu", IndiaRegionAliases.normalize("Tamil-Nadu"))
        assertEquals("", IndiaRegionAliases.normalize(" - "))
    }

    @Test
    fun `every state alias targets a canonical STATES entry, is normalized, and shadows nothing`() {
        val canonicalKeys = IndiaLocations.STATES.associateBy { IndiaRegionAliases.normalize(it) }
        IndiaRegionAliases.STATES.forEach { (alias, target) ->
            assertTrue("state alias target missing from catalog: $alias -> $target", target in IndiaLocations.STATES)
            assertEquals("state alias key not normalized: $alias", IndiaRegionAliases.normalize(alias), alias)
            assertNull("state alias shadows a canonical name: $alias", canonicalKeys[alias])
        }
    }

    @Test
    fun `every district alias targets a real district of its State, is normalized, and shadows nothing`() {
        IndiaRegionAliases.DISTRICTS.forEach { (state, aliases) ->
            assertTrue("alias table for unknown state: $state", state in IndiaLocations.STATES)
            val districts = IndiaLocations.districtsFor(state)
            val liveKeys = districts.map { IndiaRegionAliases.normalize(it) }.toSet()
            aliases.forEach { (alias, target) ->
                assertTrue("$state alias target is not a district there: $alias -> $target", target in districts)
                assertEquals("$state alias key not normalized: $alias", IndiaRegionAliases.normalize(alias), alias)
                assertTrue("$state alias shadows a live district: $alias", alias !in liveKeys)
            }
        }
    }

    @Test
    fun `canonicalState resolves legacy and variant State names`() {
        assertEquals("Odisha", IndiaLocations.canonicalState("Orissa"))
        assertEquals("Puducherry", IndiaLocations.canonicalState("Pondicherry"))
        assertEquals("Uttarakhand", IndiaLocations.canonicalState("Uttaranchal"))
        assertEquals("Jammu and Kashmir", IndiaLocations.canonicalState("Jammu & Kashmir"))
        assertEquals("Jammu and Kashmir", IndiaLocations.canonicalState("J&K"))
        assertEquals("Delhi", IndiaLocations.canonicalState("NCT of Delhi"))
        assertEquals("Delhi", IndiaLocations.canonicalState("National Capital Territory of Delhi"))
        assertEquals("Dadra and Nagar Haveli and Daman and Diu", IndiaLocations.canonicalState("Daman and Diu"))
        assertEquals("Dadra and Nagar Haveli and Daman and Diu", IndiaLocations.canonicalState("Dadra & Nagar Haveli"))
        assertEquals("Andaman and Nicobar Islands", IndiaLocations.canonicalState("Andaman & Nicobar"))
        assertEquals("Tamil Nadu", IndiaLocations.canonicalState("Tamilnadu"))
        assertEquals("Tamil Nadu", IndiaLocations.canonicalState("tamil-nadu"))
        assertEquals("Chhattisgarh", IndiaLocations.canonicalState("Chattisgarh"))
        assertEquals("Telangana", IndiaLocations.canonicalState("Telangana State"))
    }

    @Test
    fun `canonicalState embeds only whole words in the Geocoder fallback`() {
        assertEquals("Karnataka", IndiaLocations.canonicalState("Karnataka, India"))
        // "Goalpara" (an Assam district) contains the letters of Goa; it must
        // not become the state Goa.
        assertNull(IndiaLocations.canonicalState("Goalpara"))
        assertNull(IndiaLocations.canonicalState("Assamese"))
        // Prefill (default) reads the embedded whole word; strict mode, used
        // for stored/composed values, does not — "New Delhi" is a district.
        assertEquals("Delhi", IndiaLocations.canonicalState("New Delhi"))
        assertNull(IndiaLocations.canonicalState("New Delhi", allowEmbedded = false))
        assertNull(IndiaLocations.canonicalState("Karnataka, India", allowEmbedded = false))
        // Strict mode still accepts exact, normalized and aliased names.
        assertEquals("Odisha", IndiaLocations.canonicalState("Orissa", allowEmbedded = false))
        assertEquals("Jammu and Kashmir", IndiaLocations.canonicalState("Jammu & Kashmir", allowEmbedded = false))
    }

    @Test
    fun `canonicalDistrict matches exact, normalized and aliased names within the State`() {
        assertEquals("Bengaluru Urban", IndiaLocations.canonicalDistrict("Karnataka", "Bangalore"))
        assertEquals("Bengaluru Urban", IndiaLocations.canonicalDistrict("karnataka", "bengaluru  urban"))
        assertEquals("Rangareddy", IndiaLocations.canonicalDistrict("Telangana", "Ranga Reddy"))
        assertEquals("Medchal-Malkajgiri", IndiaLocations.canonicalDistrict("Telangana", "Medchal–Malkajgiri"))
        assertEquals("Hyderabad", IndiaLocations.canonicalDistrict("Telangana", " hyderabad "))
        assertEquals("Prayagraj", IndiaLocations.canonicalDistrict("Uttar Pradesh", "Allahabad"))
        assertEquals("YSR Kadapa", IndiaLocations.canonicalDistrict("Andhra Pradesh", "Y.S.R. Kadapa"))
        assertEquals("Thiruvananthapuram", IndiaLocations.canonicalDistrict("Kerala", "Trivandrum"))
        assertEquals("Hoshangabad", IndiaLocations.canonicalDistrict("Madhya Pradesh", "Narmadapuram"))
        // State given in legacy form too.
        assertEquals("Khordha", IndiaLocations.canonicalDistrict("Orissa", "Bhubaneswar"))
    }

    @Test
    fun `district history is scoped to the State that renamed it`() {
        assertEquals("Chhatrapati Sambhaji Nagar", IndiaLocations.canonicalDistrict("Maharashtra", "Aurangabad"))
        assertEquals("Aurangabad", IndiaLocations.canonicalDistrict("Bihar", "Aurangabad"))
        assertEquals("Dharashiv", IndiaLocations.canonicalDistrict("Maharashtra", "Osmanabad"))
        assertNull(IndiaLocations.canonicalDistrict("Bihar", "Osmanabad"))
    }

    @Test
    fun `canonicalDistrict never guesses`() {
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Hyd"))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Hyderabadd"))
        assertNull(IndiaLocations.canonicalDistrict("Atlantis", "Hyderabad"))
        assertNull(IndiaLocations.canonicalDistrict(null, "Hyderabad"))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", null))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "   "))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", " - "))
    }
}
