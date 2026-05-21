package com.equipseva.app.features.engineer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the engineer-location editor save gate. The Save CTA must be
 * disabled in four cases:
 *
 *   1) loading the existing saved coords;
 *   2) save in flight;
 *   3) user hasn't picked a point yet (picked coords null);
 *   4) picked coords identical to saved coords (no-op write).
 *
 * The last case is the easy regression — without it, every successful
 * load would leave Save enabled and a tap would write the same row
 * back to Postgres, triggering an updated_at touch + a realtime
 * fanout for no behavioural change.
 */
class EngineerLocationUiStateTest {

    @Test fun `canSave false while loading`() {
        val state = EngineerLocationViewModel.UiState(
            loading = true,
            pickedLatitude = 12.97,
            pickedLongitude = 77.59,
        )
        assertFalse(state.canSave)
    }

    @Test fun `canSave false while saving`() {
        val state = EngineerLocationViewModel.UiState(
            loading = false,
            saving = true,
            pickedLatitude = 12.97,
            pickedLongitude = 77.59,
        )
        assertFalse(state.canSave)
    }

    @Test fun `canSave false when no point has been picked`() {
        val state = EngineerLocationViewModel.UiState(loading = false)
        assertFalse(state.canSave)
    }

    @Test fun `canSave false when only one coord has been picked (defensive)`() {
        // Should be impossible from the UI (the picker writes lat+lng
        // atomically), but defensive: a malformed state must not
        // surface a savable button.
        val partial = EngineerLocationViewModel.UiState(
            loading = false,
            pickedLatitude = 12.97,
            pickedLongitude = null,
        )
        assertFalse(partial.canSave)
    }

    @Test fun `canSave false when picked equals saved (no-op write)`() {
        val state = EngineerLocationViewModel.UiState(
            loading = false,
            savedLatitude = 12.97,
            savedLongitude = 77.59,
            pickedLatitude = 12.97,
            pickedLongitude = 77.59,
        )
        assertFalse(state.canSave)
    }

    @Test fun `canSave true when picked differs from saved`() {
        val state = EngineerLocationViewModel.UiState(
            loading = false,
            savedLatitude = 12.97,
            savedLongitude = 77.59,
            pickedLatitude = 13.00,
            pickedLongitude = 77.59,
        )
        assertTrue(state.canSave)
    }

    @Test fun `canSave true when picking the first time (saved is null)`() {
        val state = EngineerLocationViewModel.UiState(
            loading = false,
            pickedLatitude = 12.97,
            pickedLongitude = 77.59,
        )
        assertTrue(state.canSave)
    }
}
