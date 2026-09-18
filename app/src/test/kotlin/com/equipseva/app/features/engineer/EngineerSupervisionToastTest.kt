package com.equipseva.app.features.engineer

import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Every supervision action sets its confirmation toast and then calls
 * reload(). reload() used to REPLACE the whole state with a fresh UiState, so
 * the toast it had just set was wiped microseconds later and the engineer got
 * no confirmation that their accept / decline / sign-off had landed (the
 * sibling demand-signals screen fixed the same shape by copying state).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EngineerSupervisionToastTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun row(status: String = "accepted") = EngineerGraduationRepository.SupervisionRow(
        role = "trainee",
        assignmentId = "assign-1",
        counterpartUserId = "user-2",
        repairJobId = "job-1",
        status = status,
        traineeTier = "bronze",
        supervisorTier = "silver",
        requestedAt = "2026-05-11T09:30:00Z",
    )

    @Test fun `the accept confirmation survives the reload it triggers`() = runTest(dispatcher) {
        val repo = mockk<EngineerGraduationRepository>(relaxed = true) {
            coEvery { fetchSupervisionProgress() } returns Result.success(listOf(row()))
            coEvery { acceptSupervision(any()) } returns Result.success(Unit)
        }
        val vm = EngineerSupervisionViewModel(repo)
        advanceUntilIdle()

        vm.accept("assign-1")
        advanceUntilIdle()

        assertEquals("Accepted", vm.state.value.toast)
        assertEquals(EngineerSupervisionViewModel.Status.Loaded, vm.state.value.status)
        assertEquals(1, vm.state.value.rows.size)
    }
}
