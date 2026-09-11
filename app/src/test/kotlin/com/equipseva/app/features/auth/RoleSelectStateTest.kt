package com.equipseva.app.features.auth

import com.equipseva.app.features.auth.state.FormUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the role-select gating logic. The "Confirm" CTA on the role
 * picker is bound to [RoleSelectViewModel.RoleSelectState.canConfirm];
 * a regression that allowed confirm without a selection would post
 * a null role to the server.
 */
class RoleSelectStateTest {

    @Test fun `canConfirm false when no role selected`() {
        val state = RoleSelectViewModel.RoleSelectState()
        assertFalse(state.canConfirm)
    }

    @Test fun `canConfirm true when role selected and not submitting`() {
        val state = RoleSelectViewModel.RoleSelectState(selected = UserRole.ENGINEER)
        assertTrue(state.canConfirm)
    }

    @Test fun `canConfirm false while submitting even with selection`() {
        val state = RoleSelectViewModel.RoleSelectState(
            selected = UserRole.HOSPITAL,
            form = FormUiState(submitting = true),
        )
        assertFalse(state.canConfirm)
    }

    @Test fun `default roles list exposes only active hospital and engineer roles`() {
        val state = RoleSelectViewModel.RoleSelectState()
        assertEquals(listOf(UserRole.HOSPITAL, UserRole.ENGINEER), state.roles)
    }
}
