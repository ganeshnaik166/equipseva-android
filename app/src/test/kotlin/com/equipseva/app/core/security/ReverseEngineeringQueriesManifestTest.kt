package com.equipseva.app.core.security

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Package-visibility filtering (targetSdk 30+) makes `getPackageInfo` throw
 * NameNotFoundException for every package the manifest does not declare
 * under `<queries>` — including installed ones. A detector id without its
 * `<package>` entry therefore reads as "not installed" on every device,
 * which is indistinguishable from a clean device and silently disables the
 * tamper block.
 *
 * Runs against the source-tree manifest rather than the merged one: the
 * point is to catch a contributor who extended
 * [ReverseEngineeringDetector.SUSPICIOUS_PACKAGES] without declaring the id.
 */
class ReverseEngineeringQueriesManifestTest {

    @Test
    fun `every suspicious package id is declared in the manifest queries block`() {
        val declared = declaredQueryPackages()
        val missing = ReverseEngineeringDetector.SUSPICIOUS_PACKAGES.toSet() - declared
        assertTrue(
            "AndroidManifest.xml <queries> is missing <package> entries for: $missing",
            missing.isEmpty(),
        )
    }

    @Test
    fun `the manifest declares no package id the detector never probes`() {
        // Kept tight in both directions: a leftover entry is a visibility
        // grant nothing uses, and Play reviews the queries list.
        val stale = declaredQueryPackages() - ReverseEngineeringDetector.SUSPICIOUS_PACKAGES.toSet()
        assertTrue(
            "AndroidManifest.xml declares <package> entries the detector never probes: $stale",
            stale.isEmpty(),
        )
    }

    @Test
    fun `the detector does not rely on QUERY_ALL_PACKAGES`() {
        // The specific-id declarations exist precisely so the app can avoid
        // the blanket permission and its Play policy review.
        //
        // Read the parsed permission list, not the file text: the name also
        // appears in the prose explaining why the manifest does without it,
        // so a substring search fails on the very comment that documents the
        // rule.
        val blanket = "android.permission.QUERY_ALL_PACKAGES"
        assertFalse(
            "$blanket must not be declared",
            declaredPermissions().contains(blanket),
        )
    }

    private fun declaredPermissions(): Set<String> = manifestElementNames("uses-permission")

    private fun declaredQueryPackages(): Set<String> = manifestElementNames("package")

    /** Every `android:name` carried by a top-level [tag] element in the manifest. */
    private fun manifestElementNames(tag: String): Set<String> {
        val doc = DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(manifestFile())
        val nodes = doc.getElementsByTagName(tag)
        val names = mutableSetOf<String>()
        for (i in 0 until nodes.length) {
            val name = nodes.item(i).attributes?.getNamedItem("android:name")?.nodeValue ?: continue
            names += name
        }
        return names
    }

    /** Gradle runs `:app` unit tests with cwd = `app/`; Android Studio uses the repo root. */
    private fun manifestFile(): File {
        val relPath = "app/src/main/AndroidManifest.xml"
        val candidates = listOf(File(relPath), File("../$relPath"))
        return candidates.firstOrNull { it.exists() }
            ?: error("AndroidManifest.xml not found via $candidates")
    }
}
