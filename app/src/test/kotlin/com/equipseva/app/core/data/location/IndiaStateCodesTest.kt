package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The State/UT layer of the P2.2 "official code + catalog version" contract.
 * Pins that every bundled State/UT has exactly one LGD code, that the retired
 * pre-merger codes are absent, and that resolution goes through the same
 * alias-aware canonicaliser the pickers use.
 */
class IndiaStateCodesTest {

    @Test
    fun `every catalog State or UT has an LGD code and nothing else does`() {
        assertEquals(IndiaLocations.STATES.toSet(), IndiaStateCodes.LGD.keys)
    }

    @Test
    fun `codes are unique, within the LGD range, and skip the retired 25 and 26`() {
        val codes = IndiaStateCodes.LGD.values
        assertEquals(codes.size, codes.toSet().size)
        assertTrue(codes.all { it in 1..38 })
        assertFalse(25 in codes)
        assertFalse(26 in codes)
        assertEquals(36, codes.size)
    }

    @Test
    fun `spot checks against the published numbering`() {
        assertEquals(1, IndiaStateCodes.LGD["Jammu and Kashmir"])
        assertEquals(7, IndiaStateCodes.LGD["Delhi"])
        assertEquals(29, IndiaStateCodes.LGD["Karnataka"])
        assertEquals(35, IndiaStateCodes.LGD["Andaman and Nicobar Islands"])
        assertEquals(36, IndiaStateCodes.LGD["Telangana"])
        assertEquals(37, IndiaStateCodes.LGD["Ladakh"])
        assertEquals(38, IndiaStateCodes.LGD["Dadra and Nagar Haveli and Daman and Diu"])
    }

    @Test
    fun `lgdCode resolves aliases and case through canonicalState`() {
        assertEquals(21, IndiaStateCodes.lgdCode("Orissa"))
        assertEquals(1, IndiaStateCodes.lgdCode("jammu & kashmir"))
        assertEquals(38, IndiaStateCodes.lgdCode("Daman and Diu"))
        // The other retired UT name is a live district of the merged UT, so it
        // is deliberately not a State alias and yields no code (see KDoc).
        assertNull(IndiaStateCodes.lgdCode("Dadra and Nagar Haveli"))
        assertEquals(36, IndiaStateCodes.lgdCode("  telangana "))
        assertNull(IndiaStateCodes.lgdCode("Atlantis"))
        assertNull(IndiaStateCodes.lgdCode(""))
        assertNull(IndiaStateCodes.lgdCode(null))
    }

    @Test
    fun `lgdCode and isUnionTerritory are strict unless a prefill caller opts in`() {
        // The persisted authority code must not come from an embedded phrase.
        assertNull(IndiaStateCodes.lgdCode("New Delhi"))
        assertNull(IndiaStateCodes.lgdCode("Karnataka Colony, Hyderabad, Telangana"))
        assertEquals(7, IndiaStateCodes.lgdCode("New Delhi", allowEmbedded = true))
        assertEquals(36, IndiaStateCodes.lgdCode("Karnataka Colony, Hyderabad, Telangana", allowEmbedded = true))
        assertFalse(IndiaStateCodes.isUnionTerritory("New Delhi"))
        assertTrue(IndiaStateCodes.isUnionTerritory("New Delhi", allowEmbedded = true))
    }

    @Test
    fun `stateForCode round-trips every entry and rejects retired or unknown codes`() {
        IndiaStateCodes.LGD.forEach { (name, code) ->
            assertEquals(name, IndiaStateCodes.stateForCode(code))
        }
        assertNull(IndiaStateCodes.stateForCode(25))
        assertNull(IndiaStateCodes.stateForCode(26))
        assertNull(IndiaStateCodes.stateForCode(0))
        assertNull(IndiaStateCodes.stateForCode(99))
        assertNull(IndiaStateCodes.stateForCode(null))
    }

    @Test
    fun `the eight union territories are catalog members and classify correctly`() {
        assertEquals(8, IndiaStateCodes.UNION_TERRITORIES.size)
        assertTrue(IndiaStateCodes.UNION_TERRITORIES.all { it in IndiaLocations.STATES })
        assertTrue(IndiaStateCodes.isUnionTerritory("Delhi"))
        assertTrue(IndiaStateCodes.isUnionTerritory("Pondicherry"))
        assertFalse(IndiaStateCodes.isUnionTerritory("Telangana"))
        assertFalse(IndiaStateCodes.isUnionTerritory("Atlantis"))
        assertFalse(IndiaStateCodes.isUnionTerritory(null))
        // 28 states + 8 UTs, no overlap.
        assertEquals(28, (IndiaLocations.STATES.toSet() - IndiaStateCodes.UNION_TERRITORIES).size)
    }

    @Test
    fun `provenance string says district codes are still pending`() {
        assertTrue(IndiaStateCodes.SOURCE.contains("district codes pending import"))
    }
}
