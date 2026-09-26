package com.equipseva.app.features.profile

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * A DPDP grievance starts a statutory response clock, so filing one twice
 * leaves the second request unanswerable ("duplicate of your other one") and
 * pollutes a compliance table. The composer used to stay open with its
 * description intact and Submit live again, which made a second tap the
 * obvious move.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class DpdpGrievanceSubmitGuardTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun repo(inFlight: CompletableDeferred<Unit>): DpdpGrievanceRepository =
        mockk(relaxed = true) {
            coEvery { fetchMyGrievances() } returns Result.success(emptyList())
            coEvery { fileGrievance(any(), any()) } coAnswers {
                inFlight.await()
                Result.success("grievance-1")
            }
        }

    @Test fun `a second submit while the first is in flight files nothing`() = runTest(dispatcher) {
        val inFlight = CompletableDeferred<Unit>()
        val repo = repo(inFlight)
        val vm = DpdpGrievanceViewModel(repo)

        vm.submit("deletion_request", "Please delete my data.")
        vm.submit("deletion_request", "Please delete my data.")
        advanceUntilIdle()

        coVerify(exactly = 1) { repo.fileGrievance(any(), any()) }
        inFlight.complete(Unit)
        advanceUntilIdle()
    }

    @Test fun `a filed grievance reports submitted so the composer can close`() = runTest(dispatcher) {
        val inFlight = CompletableDeferred<Unit>()
        inFlight.complete(Unit)
        val repo = repo(inFlight)
        val vm = DpdpGrievanceViewModel(repo)

        vm.submit("complaint", "Something went wrong with my data.")
        advanceUntilIdle()

        assertTrue(vm.state.value.submitted)
        assertTrue(!vm.state.value.submitting)
    }
}
