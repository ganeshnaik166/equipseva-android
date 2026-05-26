package com.equipseva.app.features.engineer

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/**
 * EngineerLocationViewModel.onPick — the WGS84 coordinate gate.
 *
 * The save gate ([EngineerLocationViewModel.UiState.canSave]) is already
 * covered by [EngineerLocationUiStateTest]. This file covers the input
 * validator: a garbled GPS callback or a future hostile callsite must not
 * write a phantom location to the server (server's lat/lng columns happily
 * accept any double; the production filter — "engineers within X km of a
 * repair job" — would then silently misbehave).
 *
 * Validation rules under test:
 *   • latitude in [-90, 90]
 *   • longitude in [-180, 180]
 *   • neither value is NaN
 *
 * Invalid input must surface an error message AND leave pickedLatitude /
 * pickedLongitude untouched, so the previously-valid pick survives.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EngineerLocationViewModelOnPickTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    private fun makeVm(): EngineerLocationViewModel {
        val signedIn = MutableStateFlow<AuthSession>(
            AuthSession.SignedIn(userId = "user-1", email = "e@x.test"),
        )
        val auth = mockk<AuthRepository> {
            coEvery { sessionState } returns signedIn
        }
        val engineerRepo = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success(null)
        }
        return EngineerLocationViewModel(auth, engineerRepo)
    }

    @Test fun `valid coords land in state without an error`() = runTest {
        val vm = makeVm()
        vm.onPick(12.97, 77.59) // Bengaluru
        val s = vm.state.value
        assertEquals(12.97, s.pickedLatitude!!, 0.0)
        assertEquals(77.59, s.pickedLongitude!!, 0.0)
        assertNull(s.errorMessage)
    }

    @Test fun `latitude above 90 is rejected with an error`() = runTest {
        val vm = makeVm()
        vm.onPick(91.0, 77.59)
        val s = vm.state.value
        assertNotNull(s.errorMessage)
        assertNull(s.pickedLatitude)
        assertNull(s.pickedLongitude)
    }

    @Test fun `latitude below minus 90 is rejected`() = runTest {
        val vm = makeVm()
        vm.onPick(-91.0, 0.0)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test fun `longitude above 180 is rejected`() = runTest {
        val vm = makeVm()
        vm.onPick(0.0, 181.0)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test fun `longitude below minus 180 is rejected`() = runTest {
        val vm = makeVm()
        vm.onPick(0.0, -181.0)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test fun `NaN latitude is rejected`() = runTest {
        val vm = makeVm()
        vm.onPick(Double.NaN, 0.0)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test fun `NaN longitude is rejected`() = runTest {
        val vm = makeVm()
        vm.onPick(0.0, Double.NaN)
        assertNotNull(vm.state.value.errorMessage)
    }

    @Test fun `a valid follow-up pick after an invalid one clears the error`() = runTest {
        val vm = makeVm()
        vm.onPick(91.0, 0.0)
        assertNotNull(vm.state.value.errorMessage)
        vm.onPick(12.97, 77.59)
        val s = vm.state.value
        assertNull(s.errorMessage)
        assertEquals(12.97, s.pickedLatitude!!, 0.0)
    }

    @Test fun `invalid pick does NOT overwrite a previously-valid pick`() = runTest {
        val vm = makeVm()
        vm.onPick(12.97, 77.59)
        vm.onPick(200.0, 200.0)
        val s = vm.state.value
        // Previous valid coords still present
        assertEquals(12.97, s.pickedLatitude!!, 0.0)
        assertEquals(77.59, s.pickedLongitude!!, 0.0)
        // But the error message surfaces
        assertNotNull(s.errorMessage)
    }
}
