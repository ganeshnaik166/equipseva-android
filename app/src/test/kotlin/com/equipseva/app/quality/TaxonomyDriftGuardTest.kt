package com.equipseva.app.quality

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Regression guard for equipment-taxonomy drift (r1504; sibling of the
 * r1503 push-kind guard).
 *
 * RepairEquipmentCategory.V04_ALLOWED (r1496) is the client's STATIC mirror
 * of the server's serviceable categories — the offline-safe fallback for the
 * Request Service picker and the sole source for the AMC wizard's
 * DEFAULT_CATEGORIES. The server truth lives in the equipment_taxonomy_class
 * seed (round486, in supabase/migrations in this repo): allowed_in_v04=true
 * rows are the ONLY types the repair_jobs / amc_contracts taxonomy-gate
 * triggers accept from non-founder users. r1496 fixed the pickers offering 9
 * server-rejected types; this test stops the mirror from silently rotting.
 *
 * Fails when:
 *  1. the seed's allowed set differs from V04_ALLOWED (add/remove the enum
 *     entry in V04_ALLOWED to match the new seed), or
 *  2. any migration UPDATEs/DELETEs equipment_taxonomy_class — the static
 *     mirror can then no longer be derived from the seed alone; re-verify
 *     V04_ALLOWED against the final table state and teach this test about
 *     the mutation. Do NOT delete the guard.
 */
class TaxonomyDriftGuardTest {

    @Test fun `V04_ALLOWED mirrors the taxonomy seed's allowed_in_v04 rows`() {
        val repoRoot = findRepoRoot()
        assertTrue(
            "Could not locate supabase/migrations from ${File(".").absolutePath} — fix this " +
                "test's root resolution; do NOT delete the guard.",
            repoRoot != null,
        )
        val migrations = File(repoRoot!!, "supabase/migrations")

        // Row shape in the seed: ('dental', 'A', true, '<reason>'),
        val rowRegex = Regex("""\('([a-z_]+)',\s*'[A-Z]+',\s*(true|false)""")
        val seedAllowed = mutableSetOf<String>()
        var seedRowsSeen = 0
        var mutationFound: String? = null
        migrations.walkTopDown()
            .filter { it.isFile && it.extension == "sql" }
            .forEach { file ->
                val text = file.readText()
                if (text.contains("INSERT INTO public.equipment_taxonomy_class")) {
                    rowRegex.findAll(text).forEach { m ->
                        seedRowsSeen++
                        if (m.groupValues[2] == "true") seedAllowed.add(m.groupValues[1])
                    }
                }
                if (Regex("(UPDATE|DELETE FROM)\\s+(public\\.)?equipment_taxonomy_class")
                        .containsMatchIn(text)
                ) {
                    mutationFound = file.name
                }
            }

        assertTrue(
            "Found no taxonomy seed rows — the INSERT moved or the row regex rotted; " +
                "fix the extractor, don't delete the guard.",
            seedRowsSeen > 0,
        )
        assertTrue(
            "Migration '$mutationFound' mutates equipment_taxonomy_class after the seed — " +
                "the V04_ALLOWED static mirror can no longer be derived from the seed alone. " +
                "Re-verify it against the final table state and update this guard.",
            mutationFound == null,
        )
        assertEquals(
            "V04_ALLOWED drifted from the server taxonomy seed — pickers would offer " +
                "server-rejected categories (or hide serviceable ones). Update " +
                "RepairEquipmentCategory.V04_ALLOWED to match.",
            seedAllowed,
            RepairEquipmentCategory.V04_ALLOWED.map { it.storageKey }.toSet(),
        )
    }

    private fun findRepoRoot(): File? =
        listOf(".", "..", "../..")
            .map(::File)
            .firstOrNull { File(it, "supabase/migrations").isDirectory }
}
