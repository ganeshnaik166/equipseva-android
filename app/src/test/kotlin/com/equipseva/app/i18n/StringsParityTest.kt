package com.equipseva.app.i18n

import org.junit.Test
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Round 514 (v0.4 P5 #9) — enforce that every key in
 * res/values/strings.xml also exists in res/values-hi/strings.xml and
 * res/values-te/strings.xml. Prevents accidental drift as new strings
 * land before the next native-speaker review pass.
 *
 * Runs against the source-tree XML, NOT the merged manifest — that's
 * intentional, the goal is to catch a developer who added an English
 * string without adding placeholder translations.
 */
class StringsParityTest {
    @Test
    fun `hi and te locales include every key from the default locale`() {
        val baseKeys = readStringKeys("app/src/main/res/values/strings.xml")
        val hiKeys = readStringKeys("app/src/main/res/values-hi/strings.xml")
        val teKeys = readStringKeys("app/src/main/res/values-te/strings.xml")

        val missingInHi = baseKeys - hiKeys
        val missingInTe = baseKeys - teKeys

        assertTrue(
            "values-hi/strings.xml is missing keys: $missingInHi",
            missingInHi.isEmpty(),
        )
        assertTrue(
            "values-te/strings.xml is missing keys: $missingInTe",
            missingInTe.isEmpty(),
        )

        // Surfacing extras only as info — a translation file with a leftover
        // key from a removed feature should drop the key so the parity stays
        // tight in both directions. Failing the build for an extra is the
        // right pressure.
        val extraInHi = hiKeys - baseKeys
        val extraInTe = teKeys - baseKeys
        assertTrue("values-hi has stale keys not in default: $extraInHi", extraInHi.isEmpty())
        assertTrue("values-te has stale keys not in default: $extraInTe", extraInTe.isEmpty())

        // Cross-check counts as a smoke against a key being silently
        // duplicated (which would change the set size).
        assertEquals(baseKeys.size, hiKeys.size)
        assertEquals(baseKeys.size, teKeys.size)
    }

    private fun readStringKeys(relPath: String): Set<String> {
        // Resolve relative to the module root regardless of where Gradle ran
        // the test from (Studio vs. CLI behave differently).
        val candidates = listOf(File(relPath), File("../$relPath"))
        val file = candidates.firstOrNull { it.exists() }
            ?: error("strings.xml not found via $candidates")
        val doc = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(file)
        val nodes = doc.getElementsByTagName("string")
        val keys = mutableSetOf<String>()
        for (i in 0 until nodes.length) {
            val node = nodes.item(i)
            val name = node.attributes.getNamedItem("name")?.nodeValue ?: continue
            // Drop strings flagged untranslatable — they're allowed to
            // exist only in the default locale (e.g. app_name placeholder
            // tokens, the razorpay_api_key meta-data tag).
            val translatable = node.attributes.getNamedItem("translatable")?.nodeValue
            if (translatable == "false") continue
            keys += name
        }
        return keys
    }
}
