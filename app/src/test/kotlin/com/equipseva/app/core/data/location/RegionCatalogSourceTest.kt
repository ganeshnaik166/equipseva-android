package com.equipseva.app.core.data.location

import java.io.File
import java.io.IOException
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RegionCatalogSourceTest {
    private val problems = mutableListOf<Throwable>()
    private fun source(allowSynthetic: Boolean, read: () -> String?) =
        RegionCatalogSource(RegionAssetReader { read() }, RegionCatalogPolicy(allowSynthetic)) { problems += it }

    @Test
    fun `no bundled asset means no catalogue and nothing to report`() = runTest {
        assertNull(source(allowSynthetic = true) { null }.catalog())
        assertTrue(problems.isEmpty())
    }

    @Test
    fun `an unreadable asset is reported and yields no catalogue`() = runTest {
        assertNull(source(allowSynthetic = true) { throw IOException("disk") }.catalog())
        assertEquals(1, problems.size)
    }

    @Test
    fun `any other reader failure is reported and cached as no catalogue`() = runTest {
        var reads = 0
        val s = source(allowSynthetic = true) { reads++; throw IllegalStateException("asset manager closed") }
        assertNull(s.catalog())
        assertNull(s.catalog())
        assertEquals(1, reads)
        assertEquals(1, problems.size)
    }

    @Test
    fun `an invalid asset is reported and never partially used`() = runTest {
        val broken = SyntheticRegions.json.replaceFirst("\"alias\": \"old riverton\"", "\"alias\": \"Old Riverton\"")
        assertNull(source(allowSynthetic = true) { broken }.catalog())
        assertTrue(problems.single() is RegionCatalogFormatException)
    }

    @Test
    fun `a synthetic catalogue is refused when the build does not allow it`() = runTest {
        assertNull(source(allowSynthetic = false) { SyntheticRegions.json }.catalog())
        assertTrue(problems.single().message!!.contains("synthetic"))
        assertNotNull(source(allowSynthetic = true) { SyntheticRegions.json }.catalog())
    }

    @Test
    fun `the asset is read once and then cached`() = runTest {
        var reads = 0
        val s = source(allowSynthetic = true) { reads++; SyntheticRegions.json }
        val first = s.catalog()
        val second = s.catalog()
        assertEquals(1, reads)
        assertTrue(first === second)
    }
}

/**
 * Release safety for the shipped asset: until an owner-approved LGD snapshot is generated, no
 * region catalogue is bundled; once one is, it must parse and must not be synthetic.
 */
class BundledRegionAssetTest {
    @Test
    fun `any bundled region catalogue is valid and real`() {
        val module = listOf(File("app"), File("."), File("../app")).map { it.canonicalFile }.distinct()
            .single { it.name == "app" && File(it, "build.gradle.kts").isFile }
        val dir = File(module, "src/main/assets/regions")
        val files = dir.listFiles()?.filter { it.isFile }.orEmpty()
        files.forEach { f ->
            assertEquals("only ${AndroidRegionAssetReader.ASSET_PATH} may be bundled", "india_regions.json", f.name)
            val text = f.readText(Charsets.UTF_8)
            val catalog = RegionCatalogParser.parse(text)
            assertFalse("a synthetic catalogue must never be bundled", catalog.isSynthetic)
            // The server must hold exactly this data: an asset regenerated under an unchanged
            // version label without its seed would make valid picks look like refusals.
            val digest = Json.parseToJsonElement(text).jsonObject["source"]!!.jsonObject["sha256"]!!.jsonPrimitive.content
            val seeds = File(module.parentFile, "supabase/migrations")
                .listFiles { m -> m.name.contains("_region_catalog_seed_") }.orEmpty()
            assertTrue(
                "the bundled catalogue ${catalog.version} needs the seed generated from the same snapshot ($digest)",
                seeds.any { s -> s.readText().let { it.contains("-- Snapshot sha256: $digest.") && it.contains("VALUES ('${catalog.version}',") } },
            )
        }
    }

    @Test
    fun `the seed check recognises the generator's seed header`() {
        // Pins the two strings the bundled-asset check looks for in a generated seed.
        val module = listOf(File("app"), File("."), File("../app")).map { it.canonicalFile }.distinct()
            .single { it.name == "app" && File(it, "build.gradle.kts").isFile }
        val generator = File(module.parentFile, "scripts/regions/build_region_catalog.mjs").readText()
        assertTrue(generator.contains("add(`-- Snapshot sha256: \${cat.digest}."))
        assertTrue(generator.contains("add(`VALUES (\${v}, "))
    }
}
