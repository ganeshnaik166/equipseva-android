package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Exact-only resolution on the synthetic catalogue. The cases mirror the server suite
 * (supabase/tests/region_catalog.test.mjs, legacy_label_exact_only) so the device and the
 * server agree on what legacy text resolves to.
 */
class RegionCatalogTest {
    private val c = SyntheticRegions.catalog

    @Test
    fun `normalisation matches the server - case and whitespace only`() {
        assertEquals("alpha state", RegionCatalog.normalizeLabel("  alpha   STATE "))
        assertEquals("alpha state", RegionCatalog.normalizeLabel("Alpha\tState\n"))
        assertEquals("northfield dist.", RegionCatalog.normalizeLabel("Northfield Dist."))
        assertNull(RegionCatalog.normalizeLabel("   "))
        assertNull(RegionCatalog.normalizeLabel(null))
    }

    @Test
    fun `only ASCII whitespace is folded - non-breaking spaces are kept, as on the server`() {
        val nbsp = Char(0xA0)
        val vt = Char(0x0B)
        assertEquals("alpha state", RegionCatalog.normalizeLabel("Alpha${vt}State"))
        assertEquals("alpha${nbsp}state", RegionCatalog.normalizeLabel("Alpha${nbsp}State"))
        assertEquals("${nbsp}alpha", RegionCatalog.normalizeLabel("${nbsp}Alpha "))
        assertEquals("$nbsp", RegionCatalog.normalizeLabel("$nbsp"))
        assertNull(c.resolveState("Alpha State$nbsp"))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", "Northfield$nbsp"))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", "North${nbsp}field"))
    }

    @Test
    fun `lookups return active records only`() {
        assertEquals("Alpha State", c.state("901")!!.name)
        assertTrue(c.state("902")!!.isUnionTerritory)
        assertNull(c.state("903"))
        assertNull(c.district("90103"))
        assertEquals("Lakeside", c.retiredDistrict("90103")!!.name)
        assertNull(c.district("99999"))
        assertNull(c.state(null))
        assertEquals(listOf("Lakeside East", "Lakeside West", "Northfield", "Riverton"), c.districtsOf("901").map { it.name })
        assertEquals(emptyList<RegionDistrict>(), c.districtsOf("999"))
    }

    @Test
    fun `State or UT names resolve only exactly`() {
        assertEquals("901", c.resolveState("Alpha State")!!.code)
        assertEquals("901", c.resolveState("  alpha   STATE ")!!.code)
        assertNull(c.resolveState("Alpha"))
        assertNull(c.resolveState("Gamma Former State"))
        assertNull(c.resolveState("Unknown State"))
    }

    @Test
    fun `district labels resolve only exactly, by name or alias, inside their own State or UT`() {
        assertEquals(RegionMatch.Resolved(c.district("90101")!!), c.resolveDistrict("901", "Northfield"))
        assertEquals(RegionMatch.Resolved(c.district("90101")!!), c.resolveDistrict("901", "NORTHFIELD"))
        assertEquals(RegionMatch.Resolved(c.district("90201")!!), c.resolveDistrict("902", "Northfield"))
        assertEquals(RegionMatch.Resolved(c.district("90102")!!), c.resolveDistrict("901", "Old Riverton"))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", "Northfield Dist."))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", "North"))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", "Hill crest"))
        assertEquals(RegionMatch.Resolved(c.district("90202")!!), c.resolveDistrict("902", "Hill crest"))
        assertEquals(RegionMatch.NoMatch, c.resolveDistrict("901", null))
        assertEquals(RegionMatch.UnknownState, c.resolveDistrict("903", "Old Town"))
        assertEquals(RegionMatch.UnknownState, c.resolveDistrict(null, "Northfield"))
    }

    @Test
    fun `an alias with two candidates is ambiguous, never a guess`() {
        val m = c.resolveDistrict("901", "Lakeside")
        assertEquals(RegionMatch.Ambiguous(listOf(c.district("90104")!!, c.district("90105")!!)), m)
    }

    @Test
    fun `picker search filters one State or UT by name or word prefix`() {
        assertEquals(listOf("90104", "90105"), c.search("901", "lake").map { it.code })
        assertEquals(listOf("90104"), c.search("901", "EAST").map { it.code })
        assertEquals(c.districtsOf("901"), c.search("901", "  "))
        assertEquals(emptyList<RegionDistrict>(), c.search("901", "hill"))
        assertEquals(listOf("90202"), c.search("902", "hill").map { it.code })
    }
}
