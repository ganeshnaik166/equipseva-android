package com.equipseva.app.i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Owner decision, 23 September 2026 (recorded in AGENTS.md, "Standing
 * product decisions"): EquipSeva ships English copy only. No Hindi or
 * Telugu translations, words, locale resource directories or language
 * pickers, anywhere in the product.
 *
 * This guard replaces round 514's `StringsParityTest`, which enforced
 * key parity between `values`, `values-hi` and `values-te`. Measured on
 * 23 September 2026 before the two directories were deleted: 724 of the
 * 759 hi/te entries were byte-identical English copies, so a device set
 * to Hindi or Telugu saw a 35-word partial translation. The decision
 * ends that state deliberately; this test keeps it from silently
 * eroding when a future round "helpfully" adds a locale folder again.
 *
 * Runs against the source tree, not the merged APK resources — the point
 * is to catch the commit that reintroduces a locale, not the runtime.
 */
class EnglishOnlyResourcesTest {

    @Test
    fun `no locale-qualified values directory exists under res`() {
        val resDir = locate("app/src/main/res")
        val localized = resDir.listFiles { f -> f.isDirectory && isLocaleQualified(f.name) }
            .orEmpty()
            .map { it.name }
            .sorted()
        assertTrue(
            "English only (owner decision 2026-09-23): remove translated resource " +
                "directories, found $localized",
            localized.isEmpty(),
        )
    }

    @Test
    fun `default strings file is present and carries the catalog`() {
        // Floor, not an exact count: proves the previous test looked at the
        // real res/ tree rather than passing vacuously against a wrong path
        // (760 strings measured on 2026-09-23).
        val strings = locate("app/src/main/res/values/strings.xml")
        val count = countStringResources(strings)
        assertTrue("expected the real string catalog, found only $count strings", count >= 500)
    }

    @Test
    fun `build script ships the en locale only`() {
        val gradle = locate("app/build.gradle.kts").readText()
        val line = gradle.lineSequence().firstOrNull { "localeFilters +=" in it }
            ?: error("localeFilters line missing from app/build.gradle.kts")
        assertEquals(
            "English only: localeFilters must list exactly \"en\" — got: ${line.trim()}",
            """localeFilters += setOf("en")""",
            line.trim(),
        )
    }

    /**
     * Android resource qualifiers that denote a locale: a 2-3 letter
     * language (`values-hi`, `values-te`, `values-en-rIN`) or a BCP-47
     * `b+` form (`values-b+sr+Latn`). Everything else — `values-night`,
     * `values-v26`, `values-sw600dp`, `values-land` — is not a locale.
     * `tv` and `car` are UI-mode qualifiers that happen to be short.
     */
    private fun isLocaleQualified(dirName: String): Boolean {
        if (!dirName.startsWith("values-")) return false
        val first = dirName.removePrefix("values-").substringBefore('-')
        if (first.startsWith("b+")) return true
        if (first in setOf("tv", "car")) return false
        return first.length in 2..3 && first.all { it in 'a'..'z' }
    }

    private fun countStringResources(file: File): Int {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        return doc.getElementsByTagName("string").length
    }

    private fun locate(relPath: String): File {
        // Studio runs tests from the module dir, the CLI from the repo root.
        val candidates = listOf(File(relPath), File("../$relPath"))
        return candidates.firstOrNull { it.exists() }
            ?: error("$relPath not found via $candidates")
    }
}
