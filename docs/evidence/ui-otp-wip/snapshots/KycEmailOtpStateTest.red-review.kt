package com.equipseva.app.features.kyc

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.UserRole
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Local OTP state contracts against the real ViewModel, with synthetic repositories.
 * Deferred operations expose both same-turn and in-flight duplicate dispatch.
 * These tests do not establish provider verification or account/email ownership fencing.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KycEmailOtpStateTest {
    private val dispatcher = StandardTestDispatcher()
    private val viewModels = mutableListOf<KycViewModel>()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }

    @After fun tearDown() {
        // Pending repository gates are cancellable even if an assertion fails.
        // Avoid onCleared's unrelated document-cleanup GlobalScope work.
        viewModels.forEach { it.viewModelScope.cancel() }
        dispatcher.scheduler.runCurrent()
        Dispatchers.resetMain()
    }

    @Test fun `editing keeps only six ASCII digits without losing leading zeros`() = runTest(dispatcher) {
        val f = fixture()
        f.vm.onEmailOtpChange("0\u0966-0\u0661 1234x567")
        assertEquals("001234", f.vm.state.value.emailOtpCode)

        f.vm.onEmailOtpChange("\u0966\u0967\u0662letters")
        assertEquals("", f.vm.state.value.emailOtpCode)
        coVerify(exactly = 0) { f.auth.verifyEmailOtp(any(), any()) }
    }

    @Test fun `complete leading-zero code reaches provider unchanged and confirmed refresh closes sheet`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        f.vm.onEmailOtpChange("001234")
        coEvery { f.profiles.fetchById(USER_ID) } returns Result.success(profile(verified = true))

        f.vm.submitEmailOtp()
        assertTrue(f.vm.state.value.verifyingEmailOtp)
        runCurrent()

        coVerify(exactly = 1) { f.auth.verifyEmailOtp(EMAIL, "001234") }
        assertTrue(f.vm.state.value.emailVerified)
        assertFalse(f.vm.state.value.verifyingEmailOtp)
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertEquals("", f.vm.state.value.emailOtpCode)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `incomplete submit never calls provider or starts verifying`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        for (code in listOf("", "0", "01234")) {
            f.vm.onEmailOtpChange(code)
            f.vm.submitEmailOtp()
            runCurrent()
            assertEquals(code, f.vm.state.value.emailOtpCode)
            assertFalse(f.vm.state.value.verifyingEmailOtp)
            assertTrue(f.vm.state.value.emailVerifySheetOpen)
        }
        coVerify(exactly = 0) { f.auth.verifyEmailOtp(any(), any()) }
    }

    @Test fun `resend clears the previous code before awaiting its response`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        f.vm.onEmailOtpChange("001234")
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { response.await() }

        f.vm.startEmailVerification()
        assertEquals("", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.sendingEmailOtp)
        runCurrent()
        coVerify(exactly = 2) { f.auth.sendEmailOtp(EMAIL) }

        response.complete(Result.success(Unit))
        runCurrent()
        assertFalse(f.vm.state.value.sendingEmailOtp)
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
        f.vm.onEmailOtpChange("000987")
        assertEquals("000987", f.vm.state.value.emailOtpCode)
    }

    @Test fun `duplicate send before dispatch and during suspended send makes one request then permits fresh resend`() = runTest(dispatcher) {
        val f = fixture()
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { response.await() }

        f.vm.startEmailVerification()
        f.vm.startEmailVerification()
        runCurrent()
        f.vm.onEmailOtpChange("001234")
        f.vm.startEmailVerification()
        runCurrent()

        coVerify(exactly = 1) { f.auth.sendEmailOtp(EMAIL) }
        assertEquals("001234", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.sendingEmailOtp)
        response.complete(Result.success(Unit))
        runCurrent()

        f.vm.startEmailVerification()
        runCurrent()
        coVerify(exactly = 2) { f.auth.sendEmailOtp(EMAIL) }
        assertFalse(f.vm.state.value.sendingEmailOtp)
        assertEquals("", f.vm.state.value.emailOtpCode)
    }

    @Test fun `duplicate submit before dispatch and during suspended verification makes one request then permits retry`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        f.vm.onEmailOtpChange("001234")
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers { response.await() }

        f.vm.submitEmailOtp()
        f.vm.submitEmailOtp()
        runCurrent()
        f.vm.submitEmailOtp()
        runCurrent()

        coVerify(exactly = 1) { f.auth.verifyEmailOtp(EMAIL, "001234") }
        assertTrue(f.vm.state.value.verifyingEmailOtp)
        response.complete(Result.failure(IOException("synthetic failure")))
        runCurrent()
        assertFalse(f.vm.state.value.verifyingEmailOtp)

        f.vm.submitEmailOtp()
        runCurrent()
        coVerify(exactly = 2) { f.auth.verifyEmailOtp(EMAIL, "001234") }
    }

    @Test fun `resend while verifying neither sends nor clears the submitted code`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        f.vm.onEmailOtpChange("001234")
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers { response.await() }
        f.vm.submitEmailOtp()
        runCurrent()

        f.vm.startEmailVerification()
        runCurrent()

        coVerify(exactly = 1) { f.auth.sendEmailOtp(EMAIL) }
        assertEquals("001234", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.verifyingEmailOtp)
        assertFalse(f.vm.state.value.sendingEmailOtp)
    }

    @Test fun `verifying blocks edit and dismissal until the pending attempt fails`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        f.vm.onEmailOtpChange("001234")
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers { response.await() }
        f.vm.submitEmailOtp()
        runCurrent()

        f.vm.onEmailOtpChange("987654")
        f.vm.closeEmailVerifySheet()
        assertEquals("001234", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
        assertTrue(f.vm.state.value.verifyingEmailOtp)

        response.complete(Result.failure(IOException("synthetic failure")))
        runCurrent()
        assertEquals(IOException().toUserMessage(), f.vm.state.value.emailOtpError)
        f.vm.onEmailOtpChange("987654")
        assertEquals("987654", f.vm.state.value.emailOtpCode)
        assertNull(f.vm.state.value.emailOtpError)
        f.vm.closeEmailVerifySheet()
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertEquals("", f.vm.state.value.emailOtpCode)
    }

    @Test fun `sending permits editing and dismissal and late send completion does not reopen sheet`() = runTest(dispatcher) {
        val f = fixture()
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { response.await() }
        f.vm.startEmailVerification()
        runCurrent()

        f.vm.onEmailOtpChange("001234")
        assertEquals("001234", f.vm.state.value.emailOtpCode)
        f.vm.closeEmailVerifySheet()
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertEquals("", f.vm.state.value.emailOtpCode)

        response.complete(Result.success(Unit))
        runCurrent()
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.sendingEmailOtp)
    }

    // Policy revised after QA reproduced: pending send -> Verify -> late send failure
    // dismissed the sheet while verification was still running. The prior permissive
    // characterization is preserved in the coordinator's raw pre-revision snapshot.
    @Test fun `pending send blocks complete submit then a fresh verify works after send succeeds`() = runTest(dispatcher) {
        val f = fixture()
        val sendResponse = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { sendResponse.await() }
        coEvery { f.profiles.fetchById(USER_ID) } returns Result.success(profile(verified = true))
        f.vm.startEmailVerification()
        runCurrent()
        f.vm.onEmailOtpChange("001234")

        f.vm.submitEmailOtp()
        runCurrent()

        coVerify(exactly = 0) { f.auth.verifyEmailOtp(any(), any()) }
        assertTrue(f.vm.state.value.sendingEmailOtp)
        assertFalse(f.vm.state.value.verifyingEmailOtp)
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
        assertEquals("001234", f.vm.state.value.emailOtpCode)
        sendResponse.complete(Result.success(Unit))
        runCurrent()
        assertFalse(f.vm.state.value.sendingEmailOtp)

        f.vm.submitEmailOtp()
        runCurrent()

        coVerify(exactly = 1) { f.auth.verifyEmailOtp(EMAIL, "001234") }
        assertTrue(f.vm.state.value.emailVerified)
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.verifyingEmailOtp)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `late send failure after attempted submit never leaves a verification running behind closed sheet`() = runTest(dispatcher) {
        val f = fixture()
        val sendResponse = CompletableDeferred<Result<Unit>>()
        val verifyResponse = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { sendResponse.await() }
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers { verifyResponse.await() }
        val messages = collectMessages(f.vm)
        val failure = IOException("synthetic delayed send failure")
        f.vm.startEmailVerification()
        runCurrent()
        f.vm.onEmailOtpChange("001234")
        f.vm.submitEmailOtp()
        runCurrent()

        // Finish the failing send before assertions to exercise the exact unsafe
        // baseline ordering, including dismissal with a pending verify operation.
        sendResponse.complete(Result.failure(failure))
        runCurrent()

        coVerify(exactly = 0) { f.auth.verifyEmailOtp(any(), any()) }
        assertFalse(f.vm.state.value.verifyingEmailOtp)
        assertFalse(f.vm.state.value.sendingEmailOtp)
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.emailVerified)
        assertEquals(listOf(failure.toUserMessage()), messages)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `verify failure retains code and open sheet preserves mapped effect and allows retry`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        val messages = collectMessages(f.vm)
        val failure = IOException("synthetic offline")
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } returns Result.failure(failure)
        f.vm.onEmailOtpChange("001234")

        f.vm.submitEmailOtp()
        runCurrent()

        assertEquals("001234", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.verifyingEmailOtp)
        assertEquals(failure.toUserMessage(), f.vm.state.value.emailOtpError)
        assertEquals(listOf(failure.toUserMessage()), messages)

        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } returns Result.success(Unit)
        coEvery { f.profiles.fetchById(USER_ID) } returns Result.success(profile(verified = true))
        f.vm.submitEmailOtp()
        assertNull("retry clears stale error before awaiting the provider", f.vm.state.value.emailOtpError)
        runCurrent()
        coVerify(exactly = 2) { f.auth.verifyEmailOtp(EMAIL, "001234") }
        assertTrue(f.vm.state.value.emailVerified)
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `dismissing a failed verification clears inline error and code before reopening`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        val failure = IOException("synthetic offline")
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } returns Result.failure(failure)
        f.vm.onEmailOtpChange("001234")
        f.vm.submitEmailOtp()
        runCurrent()
        assertEquals(failure.toUserMessage(), f.vm.state.value.emailOtpError)

        f.vm.closeEmailVerifySheet()

        assertNull(f.vm.state.value.emailOtpError)
        assertEquals("", f.vm.state.value.emailOtpCode)
        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        openSheet(f.vm)
        assertNull(f.vm.state.value.emailOtpError)
        assertEquals("", f.vm.state.value.emailOtpCode)
    }

    @Test fun `resending after verify failure clears inline error and rejected code before awaiting send`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        val failure = IOException("synthetic offline")
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } returns Result.failure(failure)
        f.vm.onEmailOtpChange("001234")
        f.vm.submitEmailOtp()
        runCurrent()
        assertEquals(failure.toUserMessage(), f.vm.state.value.emailOtpError)
        val response = CompletableDeferred<Result<Unit>>()
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers { response.await() }

        f.vm.startEmailVerification()

        assertNull(f.vm.state.value.emailOtpError)
        assertEquals("", f.vm.state.value.emailOtpCode)
        assertTrue(f.vm.state.value.sendingEmailOtp)
        runCurrent()
        coVerify(exactly = 2) { f.auth.sendEmailOtp(EMAIL) }
        response.complete(Result.success(Unit))
        runCurrent()
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.sendingEmailOtp)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `send failure still closes sheet preserves mapped effect and allows a fresh attempt`() = runTest(dispatcher) {
        val f = fixture()
        val messages = collectMessages(f.vm)
        val failure = IOException("synthetic offline")
        coEvery { f.auth.sendEmailOtp(EMAIL) } returns Result.failure(failure)

        f.vm.startEmailVerification()
        runCurrent()

        assertFalse(f.vm.state.value.emailVerifySheetOpen)
        assertFalse(f.vm.state.value.sendingEmailOtp)
        assertEquals("", f.vm.state.value.emailOtpCode)
        assertNull(f.vm.state.value.emailOtpError)
        assertEquals(listOf(failure.toUserMessage()), messages)

        coEvery { f.auth.sendEmailOtp(EMAIL) } returns Result.success(Unit)
        f.vm.startEmailVerification()
        runCurrent()
        coVerify(exactly = 2) { f.auth.sendEmailOtp(EMAIL) }
        assertTrue(f.vm.state.value.emailVerifySheetOpen)
    }

    @Test fun `cancelling view model cancels suspended verification without publishing an error effect`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        val messages = collectMessages(f.vm)
        val response = CompletableDeferred<Result<Unit>>()
        var requestExited = false
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers {
            try { response.await() } finally { requestExited = true }
        }
        f.vm.onEmailOtpChange("001234")
        f.vm.submitEmailOtp()
        runCurrent()

        f.vm.viewModelScope.cancel()
        runCurrent()

        assertTrue(requestExited)
        assertTrue(messages.isEmpty())
        assertFalse(f.vm.state.value.emailVerified)
        assertNull(f.vm.state.value.emailOtpError)
    }

    @Test fun `send returning wrapped cancellation cannot publish state or effects after scope cancellation`() = runTest(dispatcher) {
        val f = fixture()
        val messages = collectMessages(f.vm)
        val gate = CompletableDeferred<Unit>()
        var returnedCancellation = false
        coEvery { f.auth.sendEmailOtp(EMAIL) } coAnswers {
            // Mirrors repositories that wrap suspension in runCatching rather
            // than letting cancellation propagate directly to the caller.
            val result = runCatching { gate.await() }
            returnedCancellation = result.exceptionOrNull() is CancellationException
            result
        }
        f.vm.startEmailVerification()
        runCurrent()
        f.vm.onEmailOtpChange("001234")
        val beforeCancellation = f.vm.state.value
        assertTrue(beforeCancellation.sendingEmailOtp)

        f.vm.viewModelScope.cancel()
        runCurrent()

        assertTrue("repository returned cancellation as a failed Result", returnedCancellation)
        assertEquals("cancelled send must not publish any UiState change", beforeCancellation, f.vm.state.value)
        assertTrue(messages.isEmpty())
    }

    @Test fun `verify returning wrapped cancellation cannot publish state or effects after scope cancellation`() = runTest(dispatcher) {
        val f = fixture()
        openSheet(f.vm)
        val messages = collectMessages(f.vm)
        val gate = CompletableDeferred<Unit>()
        var returnedCancellation = false
        coEvery { f.auth.verifyEmailOtp(EMAIL, "001234") } coAnswers {
            val result = runCatching { gate.await() }
            returnedCancellation = result.exceptionOrNull() is CancellationException
            result
        }
        f.vm.onEmailOtpChange("001234")
        f.vm.submitEmailOtp()
        runCurrent()
        val beforeCancellation = f.vm.state.value
        assertTrue(beforeCancellation.verifyingEmailOtp)

        f.vm.viewModelScope.cancel()
        runCurrent()

        assertTrue("repository returned cancellation as a failed Result", returnedCancellation)
        assertEquals("cancelled verify must not publish any UiState change", beforeCancellation, f.vm.state.value)
        assertTrue(messages.isEmpty())
    }

    private data class Fixture(
        val vm: KycViewModel,
        val auth: AuthRepository,
        val profiles: ProfileRepository,
    )

    private fun TestScope.fixture(): Fixture {
        val sessions = MutableStateFlow<AuthSession>(AuthSession.SignedIn(USER_ID, EMAIL))
        val auth = mockk<AuthRepository> {
            every { sessionState } returns sessions
            coEvery { sendEmailOtp(any()) } returns Result.success(Unit)
            coEvery { verifyEmailOtp(any(), any()) } returns Result.success(Unit)
        }
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(USER_ID) } returns Result.success(profile())
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(USER_ID) } returns Result.success(null)
        }
        val vm = KycViewModel(
            authRepository = auth,
            engineerRepository = engineers,
            profileRepository = profiles,
            photoUploadStash = mockk(relaxed = true),
            playIntegrityClient = mockk(relaxed = true),
            locationFetcher = mockk(relaxed = true),
            userPrefs = mockk(relaxed = true),
            storageRepository = mockk(relaxed = true),
            savedStateHandle = SavedStateHandle(),
            analytics = mockk(relaxed = true),
            crashReporter = mockk(relaxed = true),
        )
        viewModels += vm
        runCurrent()
        assertFalse("synthetic profile must finish loading", vm.state.value.loading)
        assertEquals(EMAIL, vm.state.value.email)
        assertNull(vm.state.value.emailOtpError)
        return Fixture(vm, auth, profiles)
    }

    private fun TestScope.openSheet(vm: KycViewModel) {
        vm.startEmailVerification()
        runCurrent()
        assertTrue(vm.state.value.emailVerifySheetOpen)
        assertFalse(vm.state.value.sendingEmailOtp)
    }

    private fun TestScope.collectMessages(vm: KycViewModel): MutableList<String> {
        val messages = mutableListOf<String>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            vm.effects.collect { if (it is KycViewModel.Effect.ShowMessage) messages += it.text }
        }
        return messages
    }

    private fun profile(verified: Boolean = false) = Profile(
        id = USER_ID,
        email = EMAIL,
        phone = null,
        fullName = "Synthetic Engineer",
        avatarUrl = null,
        role = UserRole.ENGINEER,
        rawRoleKey = "engineer",
        roleConfirmed = true,
        onboardingCompleted = true,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
        emailVerified = verified,
    )

    private companion object {
        const val USER_ID = "otp-test-user"
        const val EMAIL = "engineer@example.test"
    }
}
