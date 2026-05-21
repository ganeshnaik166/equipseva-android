package com.equipseva.app.features.engineerprofile

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the engineer-profile editor's specialization picker contract:
 *
 *   * SPEC_CATALOG — every RepairEquipmentCategory storage key EXCEPT
 *     "other". Pinned so a refactor that drops the filter doesn't
 *     surface a meaningless "Other" chip in the picker (server-side
 *     would still accept it, but the user picks a specific category).
 *   * specDisplayName — round-trip storage key → display name via
 *     RepairEquipmentCategory.fromKey. Unknown keys fall through to
 *     "Other".
 */
class SpecCatalogAndDisplayNameTest {

    @Test fun `SPEC_CATALOG excludes the Other storage key`() {
        assertFalse(
            "other must not appear in the picker catalog",
            SPEC_CATALOG.contains("other"),
        )
        assertFalse(
            "Other must not appear in the picker catalog (case check)",
            SPEC_CATALOG.contains("Other"),
        )
    }

    @Test fun `SPEC_CATALOG count is RepairEquipmentCategory entries minus one`() {
        // entries size = 16 (15 specific + Other); catalog drops Other.
        assertEquals(
            RepairEquipmentCategory.entries.size - 1,
            SPEC_CATALOG.size,
        )
    }

    @Test fun `SPEC_CATALOG contains every non-Other category`() {
        RepairEquipmentCategory.entries
            .filter { it != RepairEquipmentCategory.Other }
            .forEach { cat ->
                assertTrue(
                    "${cat.storageKey} missing from picker catalog",
                    SPEC_CATALOG.contains(cat.storageKey),
                )
            }
    }

    @Test fun `specDisplayName resolves known storage keys via the enum`() {
        assertEquals("Imaging & radiology", specDisplayName("imaging_radiology"))
        assertEquals("Dental", specDisplayName("dental"))
        assertEquals("ENT", specDisplayName("ent"))
    }

    @Test fun `specDisplayName unknown key falls through to Other display`() {
        // Forward-compat — a future server-side category surfaces with
        // the Other label until the client is updated. Matches
        // RepairEquipmentCategory.fromKey's fallback.
        assertEquals("Other", specDisplayName("future_category"))
    }

    @Test fun `specDisplayName is case-sensitive (server emits lowercase)`() {
        // Mixed case isn't a valid storage key — pin so we don't
        // silently lowercase before matching.
        assertEquals("Other", specDisplayName("DENTAL"))
    }
}
