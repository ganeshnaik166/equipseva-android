package com.equipseva.app.features.security

import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import com.equipseva.app.testing.FakeAuthRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * End-to-end ChangePassword VM test using [FakeAuthRepository] —
 * exercises the field validation + the typed
 * [InvalidCurrentPasswordException] branch + the generic-failure
 * branch + the success path that resets the form state.
 *
 * Validation rules (per ChangePasswordViewModel.onSubmit):
 *   * Blank current → "Enter your current password" on currentPasswordError.
 *   * Blank new → "Enter a new password" on newPasswordError.
 *   * New same as current → "Choose a password different from your current one".
 *   * Weak new (via Validators.passwordWeakness) → the weakness message.
 *   * Blank confirm → "Re-enter your new password".
 *   * Mismatched confirm → "Passwords don't match".
 *
 * Repository call:
 *   * Success → state resets to defaults + Effect.Success emitted.
 *   * InvalidCurrentPasswordException → currentPasswordError = "Current
 *     password is incorrect" (no global errorMessage).
 *   * Any other failure → errorMessage carries toUserMessage output.
 */
class ChangePasswordViewModelTest {

    private lateinit var fake: FakeAuthRepository
    private lateinit var viewModel: ChangePasswordViewModel

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        fake = FakeAuthRepository()
        viewModel = ChangePasswordViewModel(fake)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun `happy path updates password and resets state`() = runTest {
        viewModel.onCurrentPasswordChange("OldPass1")
        viewModel.onNewPasswordChange("NewPass1")
        viewModel.onConfirmPasswordChange("NewPass1")
        viewModel.onSubmit()

        // Wait until the call completes (state resets to fresh UiState).
        val final = viewModel.state.first { !it.submitting && it.currentPassword.isBlank() }
        assertEquals("", final.currentPassword)
        assertEquals("", final.newPassword)
        assertEquals("", final.confirmPassword)
        assertNull(final.errorMessage)
        assertEquals(1, fake.updatePasswordCalls.size)
        val call = fake.updatePasswordCalls.single()
        assertEquals("OldPass1", call.current)
        assertEquals("NewPass1", call.newPwd)
    }

    @Test fun `blank current password is flagged and no network call fires`() {
        viewModel.onCurrentPasswordChange("")
        viewModel.onNewPasswordChange("NewPass1")
        viewModel.onConfirmPasswordChange("NewPass1")
        viewModel.onSubmit()

        val state = viewModel.state.value
        assertEquals("Enter your current password", state.currentPasswordError)
        assertTrue("no call expected", fake.updatePasswordCalls.isEmpty())
    }

    @Test fun `new password matching current is flagged before the network call`() {
        viewModel.onCurrentPasswordChange("SamePass1")
        viewModel.onNewPasswordChange("SamePass1")
        viewModel.onConfirmPasswordChange("SamePass1")
        viewModel.onSubmit()

        val state = viewModel.state.value
        assertEquals(
            "Choose a password different from your current one",
            state.newPasswordError,
        )
        assertTrue(fake.updatePasswordCalls.isEmpty())
    }

    @Test fun `mismatched confirm is flagged`() {
        viewModel.onCurrentPasswordChange("OldPass1")
        viewModel.onNewPasswordChange("NewPass1")
        viewModel.onConfirmPasswordChange("NewPass2")
        viewModel.onSubmit()

        assertEquals("Passwords don't match", viewModel.state.value.confirmPasswordError)
        assertTrue(fake.updatePasswordCalls.isEmpty())
    }

    @Test fun `InvalidCurrentPasswordException routes to currentPasswordError, not the global error`() = runTest {
        fake.updatePasswordResult = Result.failure(InvalidCurrentPasswordException())
        viewModel.onCurrentPasswordChange("WrongOld1")
        viewModel.onNewPasswordChange("NewPass1")
        viewModel.onConfirmPasswordChange("NewPass1")
        viewModel.onSubmit()

        // The VM doesn't reset on this failure — wait for submitting to settle.
        val final = viewModel.state.first { !it.submitting && it.currentPasswordError != null }
        assertEquals("Current password is incorrect", final.currentPasswordError)
        assertNull("global errorMessage shouldn't fire for invalid current", final.errorMessage)
        assertEquals(1, fake.updatePasswordCalls.size)
    }

    @Test fun `generic network failure surfaces toUserMessage in errorMessage`() = runTest {
        fake.updatePasswordResult = Result.failure(IOException("offline"))
        viewModel.onCurrentPasswordChange("OldPass1")
        viewModel.onNewPasswordChange("NewPass1")
        viewModel.onConfirmPasswordChange("NewPass1")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && it.errorMessage != null }
        assertTrue(
            "expected network copy, got ${final.errorMessage}",
            final.errorMessage?.contains("Network problem") == true,
        )
        // The current-password slot should NOT carry the error — that
        // arm is reserved for InvalidCurrentPasswordException.
        assertNull(final.currentPasswordError)
    }
}
