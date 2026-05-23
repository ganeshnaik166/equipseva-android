package com.equipseva.app.features.amc

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the AMC wizard's default equipment-category list. The contract
 * is "every RepairEquipmentCategory storage key EXCEPT `other`" —
 * AMC contracts must cover at least one known equipment family
 * because the engineer-rotation logic downstream can't reason about
 * the generic Other bucket.
 *
 * A regression that flipped to "include Other" would let hospitals
 * post AMC contracts with no usable rotation match.
 */
class CreateAmcDefaultCategoriesTest {

    @Test fun `Other storage key is intentionally absent`() {
        // Critical: the engineer-rotation RPC can't pick a specialised
        // engineer for an "other"-category contract.
        assertFalse(
            "'other' must not be in the AMC wizard's default category list",
            DEFAULT_CATEGORIES.contains("other"),
        )
        // Case-sensitivity guard — the enum's name() is "Other" but
        // storageKey is "other"; both spellings rejected.
        assertFalse(DEFAULT_CATEGORIES.contains("Other"))
    }

    @Test fun `count is RepairEquipmentCategory entries minus one`() {
        assertEquals(
            RepairEquipmentCategory.entries.size - 1,
            DEFAULT_CATEGORIES.size,
        )
    }

    @Test fun `every non-Other category surfaces`() {
        RepairEquipmentCategory.entries
            .filter { it != RepairEquipmentCategory.Other }
            .forEach { cat ->
                assertTrue(
                    "missing ${cat.storageKey} from DEFAULT_CATEGORIES",
                    DEFAULT_CATEGORIES.contains(cat.storageKey),
                )
            }
    }

    @Test fun `entries are storage keys (server-side wire format)`() {
        // Pin so a refactor doesn't accidentally start emitting
        // displayName values which the server-side CHECK constraint
        // would reject.
        assertTrue(
            "imaging_radiology snake-case storage key expected",
            DEFAULT_CATEGORIES.contains("imaging_radiology"),
        )
        assertTrue(
            "ent lowercase storage key expected",
            DEFAULT_CATEGORIES.contains("ent"),
        )
        // Display names are NOT what gets emitted.
        assertFalse(DEFAULT_CATEGORIES.contains("Imaging & radiology"))
        assertFalse(DEFAULT_CATEGORIES.contains("ENT"))
    }

    @Test fun `list ordering follows the enum declaration order`() {
        // Pin so a future tweak (e.g. alphabetical sort) is reviewed —
        // the picker UI assumes the enum order (radiology /
        // monitoring / life-support first).
        val expected = RepairEquipmentCategory.entries
            .map { it.storageKey }
            .filter { it != "other" }
        assertEquals(expected, DEFAULT_CATEGORIES)
    }

    @Test fun `no duplicates`() {
        assertEquals(DEFAULT_CATEGORIES.size, DEFAULT_CATEGORIES.toSet().size)
    }
}
