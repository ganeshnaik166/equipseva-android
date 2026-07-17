package com.equipseva.app.features.amc

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the AMC wizard's equipment-category list. Contract since r1496:
 * ONLY the v0.4 taxonomy-allowed categories (V04_ALLOWED — the static
 * mirror of equipment_taxonomy_class allowed_in_v04=true). The earlier
 * full-enum-minus-other list let hospitals tick out-of-scope categories
 * (imaging_radiology, life_support, surgical, dialysis, cardiology) or
 * not-in-taxonomy ones (physiotherapy, neonatal, hospital_furniture,
 * oncology, ent) that the amc_contracts taxonomy gate hard-rejects on
 * create — the wizard's final submit failed after 4 steps of input.
 *
 * `other` stays excluded too: the engineer-rotation logic can't reason
 * about the generic Other bucket.
 */
class CreateAmcDefaultCategoriesTest {

    @Test fun `list is exactly the v04-allowed storage keys`() {
        assertEquals(
            RepairEquipmentCategory.V04_ALLOWED.map { it.storageKey },
            DEFAULT_CATEGORIES,
        )
    }

    @Test fun `Other storage key is absent`() {
        assertFalse(DEFAULT_CATEGORIES.contains("other"))
        assertFalse(DEFAULT_CATEGORIES.contains("Other"))
    }

    @Test fun `server-rejected categories are absent (taxonomy hard-gate)`() {
        // Out of scope (allowed_in_v04 = false): Class C/D + AERB.
        listOf("imaging_radiology", "life_support", "surgical", "dialysis", "cardiology")
            .forEach { assertFalse("$it must not be offered", DEFAULT_CATEGORIES.contains(it)) }
        // Not in the taxonomy table at all (equipment_type_unknown).
        listOf("physiotherapy", "neonatal", "hospital_furniture", "oncology", "ent")
            .forEach { assertFalse("$it must not be offered", DEFAULT_CATEGORIES.contains(it)) }
    }

    @Test fun `all five serviceable categories are offered as storage keys`() {
        listOf("patient_monitoring", "laboratory", "dental", "ophthalmology", "sterilization")
            .forEach { assertTrue("missing $it", DEFAULT_CATEGORIES.contains(it)) }
        // Display names are NOT what gets emitted (server CHECK expects keys).
        assertFalse(DEFAULT_CATEGORIES.contains("Patient monitoring"))
    }

    @Test fun `no duplicates`() {
        assertEquals(DEFAULT_CATEGORIES.size, DEFAULT_CATEGORIES.toSet().size)
    }
}
