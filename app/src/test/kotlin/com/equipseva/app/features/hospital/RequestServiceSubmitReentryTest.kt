package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.FakeProfileRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * WP22.T01 (SYNC-10): a second tap on Submit while the first request is still in flight must not
 * post a second job. The screen's canSubmit guard is not enough on its own: two taps can land
 * before the button recomposes as disabled.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RequestServiceSubmitReentryTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    private val hospital = Profile(
        id = "h1", email = null, phone = "+919876543210", fullName = "Northfield General",
        avatarUrl = null, role = null, rawRoleKey = null, roleConfirmed = true,
        onboardingCompleted = true, isActive = true, organizationId = "org1",
        organizationName = null, organizationCity = null, organizationState = null,
    )

    private fun viewModel(jobs: RepairJobRepository) = RequestServiceViewModel(
        authRepository = FakeAuthRepository(AuthSession.SignedIn(userId = "h1", email = null)),
        profileRepository = FakeProfileRepository().apply { fetchByIdResult = Result.success(hospital) },
        jobRepository = jobs,
        storageRepository = mockk(relaxed = true),
        savedStateHandle = SavedStateHandle(),
        draftStore = mockk(relaxed = true),
        engineerDirectoryRepository = mockk(relaxed = true),
        analytics = mockk(relaxed = true),
        crashReporter = mockk(relaxed = true),
    ).apply {
        onIssueChange("The ventilator alarm keeps sounding")
        onSiteAddressChange("Ward 3, Northfield General")
    }

    @Test
    fun onSubmit_twiceSynchronously_createsOnce() = runTest(dispatcher) {
        val firstCallMayFinish = CompletableDeferred<Unit>()
        val jobs = mockk<RepairJobRepository>(relaxed = true)
        coEvery { jobs.create(any()) } coAnswers {
            firstCallMayFinish.await()
            Result.failure<RepairJob>(IOException("Unable to resolve host"))
        }
        val vm = viewModel(jobs)
        advanceUntilIdle()

        vm.onSubmit(selectedSlot = 0)
        vm.onSubmit(selectedSlot = 0)
        runCurrent()
        assertTrue(vm.state.value.submitting)
        vm.onSubmit(selectedSlot = 0)
        runCurrent()
        coVerify(exactly = 1) { jobs.create(any()) }

        firstCallMayFinish.complete(Unit)
        advanceUntilIdle()
        coVerify(exactly = 1) { jobs.create(any()) }
        assertFalse(vm.state.value.submitting)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test
    fun onSubmit_afterAFailedSubmitEnds_canRetry() = runTest(dispatcher) {
        val jobs = mockk<RepairJobRepository>(relaxed = true)
        coEvery { jobs.create(any()) } returns Result.failure(IOException("Unable to resolve host"))
        val vm = viewModel(jobs)
        advanceUntilIdle()

        vm.onSubmit(selectedSlot = 0)
        advanceUntilIdle()
        assertFalse(vm.state.value.submitting)

        vm.onSubmit(selectedSlot = 0)
        advanceUntilIdle()
        coVerify(exactly = 2) { jobs.create(any()) }
    }

    @Test
    fun onSubmit_valid_postsOnceAndEmitsSubmitted() = runTest(dispatcher) {
        val job = mockk<RepairJob> {
            every { id } returns "job-1"
            every { jobNumber } returns "RJ-0001"
        }
        val jobs = mockk<RepairJobRepository>(relaxed = true)
        coEvery { jobs.create(any()) } returns Result.success(job)
        val vm = viewModel(jobs)
        val effects = mutableListOf<RequestServiceViewModel.Effect>()
        backgroundScope.launch { vm.effects.collect { effects += it } }
        advanceUntilIdle()

        vm.onSubmit(selectedSlot = 0)
        advanceUntilIdle()

        coVerify(exactly = 1) { jobs.create(any()) }
        assertEquals(listOf(RequestServiceViewModel.Effect.Submitted(jobId = "job-1", jobNumber = "RJ-0001")), effects)
        assertFalse(vm.state.value.submitting)
        assertNull(vm.state.value.errorMessage)
    }
}
