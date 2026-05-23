package com.equipseva.app.features.auth

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
 * First end-to-end ViewModel test that exercises a real coroutine
 * flow against a [FakeAuthRepository].
 *
 * Why no Hilt graph here? @HiltViewModel classes can't be @Inject'd
 * directly — Hilt requires going through ViewModelProvider /
 * SavedStateHandle. Since the VM takes a plain Kotlin constructor
 * with the AuthRepository, we just instantiate it directly with the
 * fake. Hilt + fake-Supabase wiring (PR #929) is still useful when
 * the surface under test pulls in @Inject-constructed repos that
 * eagerly observe Supabase on init, but that doesn't apply here.
 *
 * `Dispatchers.setMain(StandardTestDispatcher())` is required because
 * `ForgotPasswordViewModel.onSubmit` calls
 * `viewModelScope.launch { ... }` which dispatches on the main
 * thread. The test-time dispatcher executes those coroutines
 * deterministically and surfaces the launched work to `runTest`.
 */
class ForgotPasswordViewModelTest {

    private lateinit var fake: FakeAuthRepository
    private lateinit var viewModel: ForgotPasswordViewModel

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        fake = FakeAuthRepository()
        viewModel = ForgotPasswordViewModel(fake)
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test fun `valid email triggers a single sendPasswordResetEmail and flips sent=true`() = runTest {
        viewModel.onEmailChange("user@example.com")
        viewModel.onSubmit()

        val final = viewModel.state.first { it.sent || it.errorMessage != null }
        assertTrue("sent should be true on success", final.sent)
        assertNull(final.errorMessage)
        assertEquals(false, final.submitting)
        assertEquals(listOf("user@example.com"), fake.resetEmails)
    }

    @Test fun `invalid email blocks submit and records nothing on the fake`() {
        viewModel.onEmailChange("not-an-email")
        viewModel.onSubmit()

        val state = viewModel.state.value
        assertEquals("Enter a valid email", state.emailError)
        assertEquals(false, state.sent)
        assertTrue("expected no reset emails, got ${fake.resetEmails}", fake.resetEmails.isEmpty())
    }

    @Test fun `network failure surfaces toUserMessage in errorMessage`() = runTest {
        fake.resetEmailResult = Result.failure(IOException("offline"))
        viewModel.onEmailChange("user@example.com")
        viewModel.onSubmit()

        val final = viewModel.state.first { !it.submitting && (it.sent || it.errorMessage != null) }
        assertEquals(false, final.sent)
        // toUserMessage on IOException → "Network problem..." copy.
        assertTrue(
            "expected network copy in errorMessage=${final.errorMessage}",
            final.errorMessage?.contains("Network problem") == true,
        )
    }

    @Test fun `re-submitting after success fires a second call`() = runTest {
        viewModel.onEmailChange("user@example.com")
        viewModel.onSubmit()
        viewModel.state.first { it.sent }

        viewModel.onEmailChange("other@example.com")
        viewModel.onSubmit()
        viewModel.state.first { it.sent && fake.resetEmails.size == 2 }

        assertEquals(listOf("user@example.com", "other@example.com"), fake.resetEmails)
    }

    @Test fun `email is trimmed before validation and dispatch`() = runTest {
        viewModel.onEmailChange("  user@example.com  ")
        viewModel.onSubmit()

        val final = viewModel.state.first { it.sent || it.errorMessage != null }
        assertTrue("sent should be true after trim", final.sent)
        assertEquals(listOf("user@example.com"), fake.resetEmails)
    }
}
