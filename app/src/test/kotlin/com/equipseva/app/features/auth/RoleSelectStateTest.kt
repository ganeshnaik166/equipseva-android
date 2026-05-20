package com.equipseva.app.features.auth

import com.equipseva.app.features.auth.state.FormUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two-condition canConfirm gate on the role-picker screen the
 * brand-new user lands on right after sign-up. If this gate drifts the
 * "Continue" CTA either:
 *  - stays enabled with no role picked (server rejects the update and
 *    the user sees a confusing error), or
 *  - stays enabled while a request is in flight (double-tap → double
 *    write to profiles.role).
 */
class RoleSelectStateTest {

    private val empty = RoleSelectViewModel.RoleSelectState()

    @Test fun `default state cannot confirm`() {
        // Nothing picked yet → CTA disabled. This is the screen's
        // first-paint state, so it has to default to blocked.
        assertFalse(empty.canConfirm)
    }

    @Test fun `default roles list contains every UserRole entry`() {
        // Pins the picker contents — an accidental filtering of UserRole
        // (e.g. hiding ENGINEER behind a feature flag) would otherwise
        // slip past until QA notices the missing tile.
        assertEquals(UserRole.entries, empty.roles)
    }

    @Test fun `picking a role enables confirm`() {
        val state = empty.copy(selected = UserRole.HOSPITAL)
        assertTrue(state.canConfirm)
    }

    @Test fun `every picked role enables confirm`() {
        // Catches a future role added to UserRole that, e.g., is
        // surfaced on the picker but accidentally treated as "not yet
        // selected" by the gate.
        UserRole.entries.forEach { role ->
            assertTrue(
                "selected=${role.name} should enable confirm",
                empty.copy(selected = role).canConfirm,
            )
        }
    }

    @Test fun `submitting blocks confirm even when role is picked`() {
        val state = empty.copy(
            selected = UserRole.ENGINEER,
            form = FormUiState(submitting = true),
        )
        assertFalse(state.canConfirm)
    }

    @Test fun `prior error does not block confirm once role is picked`() {
        // After a failed confirm, the form holds an errorMessage but is
        // no longer submitting — the user has to be able to retry.
        val state = empty.copy(
            selected = UserRole.ENGINEER,
            form = FormUiState(submitting = false, errorMessage = "Network down"),
        )
        assertTrue(state.canConfirm)
    }

    @Test fun `submitting still blocks confirm when no role picked`() {
        // Defensive: shouldn't happen (submit can't start without a
        // pick) but the gate has to stay closed regardless.
        val state = empty.copy(form = FormUiState(submitting = true))
        assertFalse(state.canConfirm)
    }
}
