package com.equipseva.app.quality

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Regression guard for the locale-format defect class the 2026-07 screen audits
 * fixed ~a dozen times (r1458/r1463/r1467/r1473, …).
 *
 * `"%.1f".format(x)` uses Kotlin's String.format extension, which formats with
 * Locale.getDefault(). On a comma-decimal locale (de/fr/hi/pt/…) that renders
 * "12,5" instead of "12.5" — reads to the user as a data/typo bug. The app
 * convention is an explicit locale:
 *   String.format(java.util.Locale.US, "%.1f", x)   // or Locale.ROOT / ENGLISH
 *   "%.1f".format(java.util.Locale.US, x)           // the (Locale, args) overload
 *
 * This test scans main/ sources and fails if a float/scientific printf literal
 * is `.format()`-ed with no Locale in view. If it fails: add an explicit Locale.
 * (Plain %d is locale-inert and intentionally NOT flagged; %,d grouping is rare
 * and can be added here if it ever appears.)
 */
class LocaleFormatGuardTest {

    // A string literal carrying a float/scientific printf spec (%f/%e/%g with
    // optional flags/width/precision), immediately `.format(`-ed — i.e. the
    // Kotlin String extension, NOT `String.format(Locale, "...", …)` (there the
    // literal is an argument, not the receiver, so this pattern doesn't match).
    private val riskyFormat = Regex(""""[^"\n]*%[-#+ 0,]*\d*(?:\.\d+)?[feEgG][^"\n]*"\s*\.format\s*\(""")

    @Test fun `no default-locale float formatting in main sources`() {
        val root = findMainKotlinRoot()
        assertTrue(
            "Could not locate src/main/kotlin from ${File(".").absolutePath} — fix this " +
                "test's root resolution; do NOT delete the guard.",
            root != null && root.isDirectory,
        )

        val offenders = buildList {
            root!!.walkTopDown()
                .filter { it.isFile && it.extension == "kt" }
                .forEach { file ->
                    val lines = file.readLines()
                    lines.forEachIndexed { i, line ->
                        val trimmed = line.trimStart()
                        if (trimmed.startsWith("//") || trimmed.startsWith("*")) return@forEachIndexed
                        if (!riskyFormat.containsMatchIn(line)) return@forEachIndexed
                        // A Locale on this line or the next (multi-line format
                        // call) means the safe overload is in use — not an offender.
                        val window = line + (lines.getOrNull(i + 1) ?: "")
                        if (!window.contains("Locale")) {
                            add("${file.path}:${i + 1}  ${line.trim()}")
                        }
                    }
                }
        }

        assertTrue(
            "Default-locale float formatting found — use String.format(java.util.Locale.US, \"%.1f\", x):\n" +
                offenders.joinToString("\n"),
            offenders.isEmpty(),
        )
    }

    private fun findMainKotlinRoot(): File? =
        listOf("src/main/kotlin", "app/src/main/kotlin", "../app/src/main/kotlin")
            .map(::File)
            .firstOrNull { it.isDirectory }
}
