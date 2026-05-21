package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the label-rendering for AMC category keys. The override map
 * exists because pure title-case mangles the medical acronyms (CT scan
 * → "Ct Scan", MRI → "Mri"). A regression here surfaces on the AMC
 * picker + every contract card.
 */
class AmcCategoryLabelTest {

    @Test fun `acronym overrides render with the casing the override map specifies`() {
        assertEquals("CT Scan", amcCategoryLabel("ct_scan"))
        assertEquals("MRI", amcCategoryLabel("mri"))
        assertEquals("ICU", amcCategoryLabel("icu"))
        assertEquals("X-ray", amcCategoryLabel("x_ray"))
        assertEquals("ENT", amcCategoryLabel("ent"))
    }

    @Test fun `unknown key snake-cased splits to title-case words`() {
        assertEquals("Patient Monitor", amcCategoryLabel("patient_monitor"))
    }

    @Test fun `unknown key hyphenated splits to title-case words`() {
        assertEquals("Defib Trolley", amcCategoryLabel("defib-trolley"))
    }

    @Test fun `single-word key gets first-letter capitalised`() {
        assertEquals("Ventilator", amcCategoryLabel("ventilator"))
    }

    @Test fun `empty string round-trips empty`() {
        // Defensive: the join + capitalise pipeline shouldn't NPE on
        // an empty input — pins the no-element split behaviour.
        assertEquals("", amcCategoryLabel(""))
    }
}
