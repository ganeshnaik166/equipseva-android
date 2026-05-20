package com.equipseva.app.features.engineer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The Engineer service-location editor (engineer/service_location) lets
 * an engineer move their base coords without re-running KYC. canSave
 * has to enforce: not loading/saving, a coord is picked, AND the picked
 * coord differs from the saved one — otherwise the Save CTA stays
 * available even when there's nothing to write.
 */
class EngineerLocationUiStateTest {

    private val saved = EngineerLocationViewModel.UiState(
        loading = false,
        savedLatitude = 12.97,
        savedLongitude = 77.59,
        pickedLatitude = 12.97,
        pickedLongitude = 77.59,
    )

    @Test fun `unchanged pick blocks save`() {
        // Picked == saved → nothing to write.
        assertFalse(saved.canSave)
    }

    @Test fun `moved pick enables save`() {
        val moved = saved.copy(pickedLatitude = 13.0, pickedLongitude = 77.6)
        assertTrue(moved.canSave)
    }

    @Test fun `moving only one axis still triggers a change`() {
        assertTrue(saved.copy(pickedLatitude = 13.0).canSave)
        assertTrue(saved.copy(pickedLongitude = 77.6).canSave)
    }

    @Test fun `missing pick blocks save`() {
        assertFalse(saved.copy(pickedLatitude = null).canSave)
        assertFalse(saved.copy(pickedLongitude = null).canSave)
    }

    @Test fun `loading or saving blocks regardless of pick`() {
        val moved = saved.copy(pickedLatitude = 13.0)
        assertFalse(moved.copy(loading = true).canSave)
        assertFalse(moved.copy(saving = true).canSave)
    }

    @Test fun `first-time pick with no saved coords enables save`() {
        // Engineer has never set their base coords (e.g. legacy row);
        // any picked coord is a change.
        val firstTime = EngineerLocationViewModel.UiState(
            loading = false,
            savedLatitude = null,
            savedLongitude = null,
            pickedLatitude = 12.97,
            pickedLongitude = 77.59,
        )
        assertTrue(firstTime.canSave)
    }
}
