package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.testing.AuthAuditFixtures
import com.equipseva.app.features.auth.UserRole
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * Pins the submit-time hospital-phone gate.
 *
 * The number is cached once, when the form binds, and the gate is a
 * hard refusal that tells the hospital to go to Profile → Phone number.
 * A hospital that FOLLOWS that instruction returns to a viewmodel that
 * survived in the back stack with the stale null still cached, so the
 * app kept refusing the booking and kept giving the same instruction —
 * an unbreakable loop out of a screen with no other exit.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RequestServicePhoneGateTest {

    private val viewModels = mutableListOf<RequestServiceViewModel>()

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }

    @After fun tearDown() {
        viewModels.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private fun profile(phone: String?): Profile = AuthAuditFixtures
        .confirmedProfile(id = "A", role = UserRole.HOSPITAL)
        .copy(phone = phone)

    private fun vm(
        fixture: DraftStoreFixture,
        profileRepo: ProfileRepository,
        jobRepo: RepairJobRepository,
    ) = RequestServiceViewModel(
        profileRepository = profileRepo,
        jobRepository = jobRepo,
        storageRepository = mockk(relaxed = true),
        savedStateHandle = SavedStateHandle(),
        draftStore = fixture.store,
        engineerDirectoryRepository = mockk(relaxed = true),
        analytics = mockk(relaxed = true),
        crashReporter = mockk(relaxed = true),
    ).also { viewModels += it }

    private fun jobs() = mockk<RepairJobRepository> {
        coEvery { create(any()) } returns Result.success(mockk(relaxed = true))
    }

    private fun RequestServiceViewModel.fillValidForm() {
        onIssueChange("Ventilator alarms continuously during use")
        onSiteAddressChange("Ward 3, Apollo Hospital, Hyderabad")
    }

    @Test fun `a phone added after the form bound unblocks the booking`() = runTest {
        val fixture = DraftStoreFixture(this)
        // Bind sees no phone; by submit time the hospital has followed
        // the instruction and added one.
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } returnsMany listOf(
                Result.success(profile(null)),
                Result.success(profile("+919999999999")),
            )
        }
        val jobs = jobs()
        val model = vm(fixture, profiles, jobs)
        runCurrent()
        model.fillValidForm()

        model.onSubmit(3)
        runCurrent()

        coVerify(exactly = 1) { jobs.create(any()) }
        assertNull("no refusal may survive a successful re-read", model.state.value.errorMessage)
    }

    @Test fun `a hospital that really has no phone still gets the actionable instruction`() = runTest {
        val fixture = DraftStoreFixture(this)
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } returns Result.success(profile(null))
        }
        val jobs = jobs()
        val model = vm(fixture, profiles, jobs)
        runCurrent()
        model.fillValidForm()

        model.onSubmit(3)
        runCurrent()

        coVerify(exactly = 0) { jobs.create(any()) }
        // Naming the destination is the whole value of this copy: the
        // engineer who takes the job cannot unblock themselves later.
        assertEquals(PHONE_REQUIRED_MESSAGE, model.state.value.errorMessage)
        assertTrue(PHONE_REQUIRED_MESSAGE.contains("Profile"))
    }

    @Test fun `a failed profile re-read is reported as a fetch problem, not as a missing phone`() = runTest {
        val fixture = DraftStoreFixture(this)
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } returnsMany listOf(
                Result.success(profile(null)),
                Result.failure(IOException("offline")),
            )
        }
        val jobs = jobs()
        val model = vm(fixture, profiles, jobs)
        runCurrent()
        model.fillValidForm()

        model.onSubmit(3)
        runCurrent()

        coVerify(exactly = 0) { jobs.create(any()) }
        val msg = model.state.value.errorMessage
        assertNotNull(msg)
        // Critical pin: a hospital whose phone is on file but whose
        // profile fetch failed must not be told to add a phone they
        // already have — they would go to Profile, see the number, and
        // have nowhere left to go.
        assertTrue("got: $msg", msg != PHONE_REQUIRED_MESSAGE)
    }

    @Test fun `a second Post tap during the re-read does not double-submit`() = runTest {
        val fixture = DraftStoreFixture(this)
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } returnsMany listOf(
                Result.success(profile(null)),
                Result.success(profile("+919999999999")),
                Result.success(profile("+919999999999")),
            )
        }
        val jobs = jobs()
        val model = vm(fixture, profiles, jobs)
        runCurrent()
        model.fillValidForm()

        model.onSubmit(3)
        model.onSubmit(3)
        runCurrent()

        coVerify(exactly = 1) { jobs.create(any()) }
    }
}
