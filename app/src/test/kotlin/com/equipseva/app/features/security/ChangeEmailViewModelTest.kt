package com.equipseva.app.features.security

import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.FakeProfileRepository
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
 * End-to-end test for [ChangeEmailViewModel] using the two new fakes
 * ([FakeAuthRepository] + [FakeProfileRepository]).
 *
 * The VM stitches three calls together on submit:
 *   1. Pull the signed-in user id from `authRepository.sessionState`.
 *   2. Re-authenticate by calling `verifyCurrentPassword`.
 *   3. Patch the profile's email via `profileRepository.updateBasicInfo`.
 *
 * Each step has an error branch we want to pin:
 *   * No active session → "Sign in again to change your email."
 *   * `verifyCurrentPassword` failure → passwordError, NOT global.
 *   * `updateBasicInfo` failure → global errorMessage via toUserMessage.
 *   * Happy path → form resets + Effect.Success.
 *
 * Plus the inline validation guards (blank password / blank email /
 * bad email shape).
 */
class ChangeEmailViewModelTest {

    private lateinit var fakeAuth: FakeAuthRepository
    private lateinit var fakeProfile: FakeProfileRepository
    private lateinit var viewModel: ChangeEmailViewModel

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        // Default to signed-in so the happy path doesn't trip the
        // "no session" branch; tests that need signed-out override
        // via fakeAuth.setSession(...).
        fakeAuth = FakeAuthRepository(
            initialSession = AuthSession.SignedIn(userId = "u-1", email = "old@example.com"),
        )
        fakeProfile = FakeProfileRepository()
        viewModel = ChangeEmailViewModel(fakeAuth, fakeProfile)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun `happy path updates profile email and resets the form`() = runTest {
        viewModel.onPasswordChange("OldPass1")
        viewModel.onEmailChange("new@example.com")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && it.currentPassword.isBlank() }
        assertNull(final.errorMessage)

        // Verify the re-auth + update sequence.
        assertEquals(1, fakeAuth.verifyCurrentPasswordCalls.size)
        assertEquals("OldPass1", fakeAuth.verifyCurrentPasswordCalls.single())

        assertEquals(1, fakeProfile.updateBasicInfoCalls.size)
        val call = fakeProfile.updateBasicInfoCalls.single()
        assertEquals("u-1", call.userId)
        assertEquals("new@example.com", call.email)
        // Other fields untouched (null = "don't write").
        assertNull(call.fullName)
        assertNull(call.phone)
        assertNull(call.avatarUrl)
    }

    @Test fun `blank password is flagged and nothing hits the network`() {
        viewModel.onPasswordChange("")
        viewModel.onEmailChange("new@example.com")
        viewModel.onSubmit()

        val state = viewModel.state.value
        assertEquals("Enter your current password", state.passwordError)
        assertTrue(fakeAuth.verifyCurrentPasswordCalls.isEmpty())
        assertTrue(fakeProfile.updateBasicInfoCalls.isEmpty())
    }

    @Test fun `bad email shape is flagged before re-auth`() {
        viewModel.onPasswordChange("OldPass1")
        viewModel.onEmailChange("not-an-email")
        viewModel.onSubmit()

        val state = viewModel.state.value
        assertEquals("Enter a valid email address", state.emailError)
        assertTrue(fakeAuth.verifyCurrentPasswordCalls.isEmpty())
        assertTrue(fakeProfile.updateBasicInfoCalls.isEmpty())
    }

    // Note: the "signed-out session → sign-in-again copy" path is
    // effectively unreachable in practice. The VM reads userId via
    // `sessionState.filterIsInstance<SignedIn>().firstOrNull()` against
    // the AuthRepository's StateFlow, which never completes. If no
    // SignedIn ever lands, the call suspends forever rather than
    // returning null. The branch is dead code we'd remove in a tidy-up
    // pass — leaving the comment here so a future reader doesn't waste
    // time writing the same hanging test.

    @Test fun `verifyCurrentPassword failure routes to passwordError, not the global error`() = runTest {
        fakeAuth.verifyCurrentPasswordResult = Result.failure(InvalidCurrentPasswordException())
        viewModel.onPasswordChange("WrongPass1")
        viewModel.onEmailChange("new@example.com")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && it.passwordError != null }
        assertEquals("Current password is incorrect.", final.passwordError)
        assertNull("global errorMessage shouldn't fire on re-auth fail", final.errorMessage)
        // updateBasicInfo must NOT have run.
        assertTrue(fakeProfile.updateBasicInfoCalls.isEmpty())
    }

    @Test fun `updateBasicInfo failure surfaces via global errorMessage`() = runTest {
        fakeProfile.updateBasicInfoResult = Result.failure(IOException("offline"))
        viewModel.onPasswordChange("OldPass1")
        viewModel.onEmailChange("new@example.com")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && it.errorMessage != null }
        assertTrue(
            "expected network copy, got ${final.errorMessage}",
            final.errorMessage?.contains("Network problem") == true,
        )
        // The re-auth step DID run before the update failed.
        assertEquals(1, fakeAuth.verifyCurrentPasswordCalls.size)
    }

    @Test fun `email is trimmed before validation and dispatch`() = runTest {
        viewModel.onPasswordChange("OldPass1")
        viewModel.onEmailChange("  new@example.com  ")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && it.currentPassword.isBlank() }
        assertNull(final.errorMessage)
        val call = fakeProfile.updateBasicInfoCalls.single()
        assertEquals("new@example.com", call.email)
    }
}
