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
        // A trailing "district"/"dist" label is dropped; the word inside a name is not.
        assertEquals("rangareddy", IndiaRegionAliases.normalize("Rangareddy District"))
        assertEquals("medak", IndiaRegionAliases.normalize("Medak Dist."))
        assertEquals("rangareddy", IndiaRegionAliases.normalize("Rangareddy Distt"))
        assertEquals("district nine", IndiaRegionAliases.normalize("District Nine"))
    }

    @Test
    fun `Geocoder district labels resolve strictly through normalization and aliases`() {
        assertEquals("Rangareddy", IndiaLocations.canonicalDistrict("Telangana", "Rangareddy District"))
        assertEquals("Rangareddy", IndiaLocations.canonicalDistrict("Telangana", "K.V.Rangareddy"))
        assertEquals("Medchal-Malkajgiri", IndiaLocations.canonicalDistrict("Telangana", "Malkajgiri"))
        assertEquals("Gautam Buddha Nagar", IndiaLocations.canonicalDistrict("Uttar Pradesh", "Gautam Buddh Nagar"))
        assertEquals("Karimganj", IndiaLocations.canonicalDistrict("Assam", "Sribhumi"))
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
        assertEquals("Dadra and Nagar Haveli and Daman and Diu", IndiaLocations.canonicalState("DNH & DD"))
        // The retired UT "Dadra and Nagar Haveli" is a live district of the
        // merged UT, so it is deliberately not a State alias (see the
        // collision guard below); it resolves as a district instead.
        assertNull(IndiaLocations.canonicalState("Dadra & Nagar Haveli"))
        assertEquals(
            "Dadra and Nagar Haveli",
            IndiaLocations.canonicalDistrict("Dadra and Nagar Haveli and Daman and Diu", "Dadra & Nagar Haveli"),
        )
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
        // The embedded step runs on normalized text, so punctuation and
        // ampersands do not defeat it, and the rightmost embedded name wins.
        assertEquals("Tamil Nadu", IndiaLocations.canonicalState("Tamil-Nadu, India"))
        assertEquals("Jammu and Kashmir", IndiaLocations.canonicalState("Jammu & Kashmir, India"))
        assertEquals("Telangana", IndiaLocations.canonicalState("Karnataka Colony, Hyderabad, Telangana"))
        // A State named twice keeps its last position.
        assertEquals("Goa", IndiaLocations.canonicalState("Goa Road, Karnataka, Goa"))
        assertEquals("Telangana", IndiaLocations.canonicalState("Telangana Colony, Karnataka, Telangana"))
    }

    @Test
    fun `canonicalDistrict is strict by default and embeds only for prefill`() {
        assertNull(IndiaLocations.canonicalDistrict("Goa Velha", "North Goa"))
        assertEquals("North Goa", IndiaLocations.canonicalDistrict("Goa Velha", "North Goa", allowEmbedded = true))
        // A trailing "District" label is stripped by normalization, so this is
        // an exact match even in strict mode; a genuinely embedded phrase is not.
        assertEquals("Hyderabad", IndiaLocations.canonicalDistrict("Telangana", "Hyderabad District"))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Greater Hyderabad Area"))
        assertEquals("Hyderabad", IndiaLocations.canonicalDistrict("Telangana", "Greater Hyderabad Area", allowEmbedded = true))
        // Longest embedded district wins over a shorter one it contains.
        assertEquals(
            "North West Delhi",
            IndiaLocations.canonicalDistrict("Delhi", "North West Delhi district", allowEmbedded = true),
        )
        // Even prefill never accepts a partial word.
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Hyd", allowEmbedded = true))
        // A label naming another administrative unit is not a district, even
        // when it embeds a district's name.
        assertNull(IndiaLocations.canonicalDistrict("Maharashtra", "Nashik Division", allowEmbedded = true))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Greater Hyderabad Municipal Corporation", allowEmbedded = true))
        assertNull(IndiaLocations.canonicalDistrict("Telangana", "Medak Zone", allowEmbedded = true))
        // Real names that contain such words as part of the name still resolve.
        assertEquals("Kamrup Metropolitan", IndiaLocations.canonicalDistrict("Assam", "Kamrup Metropolitan", allowEmbedded = true))
        assertEquals("Kanpur Nagar", IndiaLocations.canonicalDistrict("Uttar Pradesh", "Kanpur Nagar district", allowEmbedded = true))
    }

    @Test
    fun `State names and aliases never double as district names except the recorded cases`() {
        val districtKeys = IndiaLocations.STATES
            .flatMap { IndiaLocations.districtsFor(it) }
            .map { IndiaRegionAliases.normalize(it) }
            .toSet()
        // A state alias that is also a district name would let parseLegacyCity
        // read a lone district as its State (the retired UT "Dadra and Nagar
        // Haveli" was removed for exactly that reason).
        val aliasCollisions = IndiaRegionAliases.STATES.keys.filter { it in districtKeys }.toSet()
        assertEquals("state alias keys that are also district names", emptySet<String>(), aliasCollisions)
        // Three single-district UTs share their name with their district.
        val canonicalCollisions = IndiaLocations.STATES
            .map { IndiaRegionAliases.normalize(it) }
            .filter { it in districtKeys }
            .toSet()
        assertEquals(setOf("chandigarh", "lakshadweep", "puducherry"), canonicalCollisions)
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
