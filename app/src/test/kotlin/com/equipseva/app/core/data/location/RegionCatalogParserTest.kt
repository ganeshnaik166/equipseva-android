package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

internal object SyntheticRegions {
    /** The synthetic two-State/UT catalogue that mirrors supabase/tests/region_catalog.test.mjs. */
    val json: String by lazy {
        requireNotNull(SyntheticRegions::class.java.getResource("/regions/synthetic_catalog.json")) {
            "missing test resource regions/synthetic_catalog.json"
        }.readText()
    }
    val catalog: RegionCatalog by lazy { RegionCatalogParser.parse(json) }
}

class RegionCatalogParserTest {
    private fun rejects(text: String, message: String) {
        val e = assertThrows(RegionCatalogFormatException::class.java) { RegionCatalogParser.parse(text) }
        assertTrue("expected '$message' in '${e.message}'", e.message.orEmpty().contains(message))
    }

    private fun mutate(from: String, to: String): String {
        val src = SyntheticRegions.json
        require(src.contains(from)) { "fixture does not contain $from" }
        return src.replaceFirst(from, to)
    }

    @Test
    fun `the synthetic catalogue parses with its version, flag and counts`() {
        val c = SyntheticRegions.catalog
        assertEquals("synthetic-v2", c.version)
        assertTrue(c.isSynthetic)
        assertEquals(listOf("901", "902"), c.states.map { it.code })
        assertEquals(6, c.districtCount)
        assertEquals(listOf("90104", "90105"), c.retiredDistrict("90103")!!.replacedBy)
    }

    @Test
    fun `format, version and emptiness are enforced`() {
        rejects(mutate("\"format\": 1", "\"format\": 2"), "unsupported format")
        rejects(mutate("\"version\": \"synthetic-v2\"", "\"version\": \"Synthetic V2\""), "invalid version")
        rejects(mutate("\"version\": \"synthetic-v2\"", "\"version\": \"v2\""), "invalid version")
        rejects("{", "not a region catalogue asset")
        rejects("""{"format":1,"version":"x-empty","source":{"url":"u","retrieved_on":"d","sha256":"s"},"states":[],"districts":[]}""", "empty catalogue")
    }

    @Test
    fun `unknown keys are refused rather than ignored`() {
        rejects(mutate("\"synthetic\": true,", "\"synthetic\": true, \"extra\": 1,"), "not a region catalogue asset")
    }

    @Test
    fun `codes, names and kinds follow the server constraints`() {
        rejects(mutate("{ \"code\": \"901\", \"name\": \"Alpha State\"", "{ \"code\": \"9011\", \"name\": \"Alpha State\""), "invalid State/UT code")
        rejects(mutate("{ \"code\": \"90101\", \"state\": \"901\"", "{ \"code\": \"9010199\", \"state\": \"901\""), "invalid district code")
        rejects(mutate("\"name\": \"Riverton\"", "\"name\": \" Riverton\""), "invalid name")
        rejects(mutate("\"name\": \"Riverton\"", "\"name\": \"${"R".repeat(65)}\""), "invalid name")
        rejects(mutate("\"kind\": \"union_territory\"", "\"kind\": \"territory\""), "invalid kind")
    }

    @Test
    fun `codes and names must be unique`() {
        rejects(mutate("{ \"code\": \"902\", \"name\": \"Beta Territory\"", "{ \"code\": \"901\", \"name\": \"Beta Territory\""), "duplicate State/UT code")
        rejects(mutate("\"name\": \"Beta Territory\"", "\"name\": \"alpha  state\""), "duplicate State/UT name")
        rejects(mutate("{ \"code\": \"90102\", \"state\": \"901\"", "{ \"code\": \"90101\", \"state\": \"901\""), "duplicate district code")
        rejects(mutate("\"code\": \"90103\", \"state\": \"901\"", "\"code\": \"90101\", \"state\": \"901\""), "duplicate district code")
        rejects(mutate("\"name\": \"Riverton\"", "\"name\": \"NORTHFIELD\""), "duplicate district name")
    }

    @Test
    fun `the same district name is allowed in two States or UTs`() {
        val c = SyntheticRegions.catalog
        assertEquals("Northfield", c.district("90101")!!.name)
        assertEquals("Northfield", c.district("90201")!!.name)
    }

    @Test
    fun `every district needs a known parent and replacements must be known`() {
        rejects(mutate("{ \"code\": \"90102\", \"state\": \"901\"", "{ \"code\": \"90102\", \"state\": \"999\""), "unknown State/UT")
        rejects(mutate("\"replaced_by\": [\"90104\", \"90105\"]", "\"replaced_by\": [\"90104\", \"99999\"]"), "unknown replacement")
        rejects(mutate("\"replaced_by\": [\"90104\", \"90105\"]", "\"replaced_by\": [\"90103\"]"), "unknown replacement")
    }

    @Test
    fun `aliases must be normalised and point at an active district of their own State or UT`() {
        rejects(mutate("\"alias\": \"old riverton\"", "\"alias\": \"Old Riverton\""), "not stored normalised")
        rejects(mutate("\"alias\": \"old riverton\"", "\"alias\": \"old  riverton\""), "not stored normalised")
        rejects(mutate("\"alias\": \"hill crest\", \"district\": \"90202\"", "\"alias\": \"hill crest\", \"district\": \"90101\""), "does not point at an active district of 902")
        rejects(mutate("\"alias\": \"old riverton\", \"district\": \"90102\"", "\"alias\": \"old riverton\", \"district\": \"90103\""), "does not point at an active district")
        rejects(mutate("\"kind\": \"common_spelling\"", "\"kind\": \"guess\""), "invalid alias kind")
        rejects(
            mutate(
                "{ \"state\": \"901\", \"alias\": \"lakeside\", \"district\": \"90105\", \"kind\": \"legacy_bundled\" }",
                "{ \"state\": \"901\", \"alias\": \"lakeside\", \"district\": \"90104\", \"kind\": \"legacy_bundled\" }",
            ),
            "duplicate alias",
        )
    }
}
