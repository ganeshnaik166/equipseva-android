package com.equipseva.app.features.kyc

import androidx.lifecycle.SavedStateHandle
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.location.LocationFetcher
import com.equipseva.app.core.security.IntegrityVerifier
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

// Round 421 — revive the KycViewModelTest suite. The placeholder
// @Ignore'd in round 232 (PR #225 follow-up) was blocked on extracting
// LocationFetcher / UserPrefs / StorageRepository to interfaces. We
// avoided the production refactor by leaning on the existing mockk
// dependency (round 328 added it for outbox handler tests) and using
// relaxed mocks for the concrete-class deps.
//
// Reviving the four most-valuable original assertions:
//   1. aadhaar validator rejects non-12-digit input
//   2. save() persists certificates with type discriminator
//   3. hydrate splits server-side certificates into aadhaar/cert slots
//   4. save() surfaces repository failure as a user message
//
// The original "no specialization selected" test is dropped — production
// stopped gating submission on specializations (see KycViewModel save()
// comment around line ~943).
@OptIn(ExperimentalCoroutinesApi::class)
class KycViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    // ---------------------------------------------------------------------
    //  Helpers
    // ---------------------------------------------------------------------

    private val signedInSession = MutableStateFlow<AuthSession>(
        AuthSession.SignedIn(userId = "user-1", email = "e@x.test"),
    )

    private fun engineer(
        certificates: List<EngineerCertificate> = emptyList(),
        verificationStatus: VerificationStatus = VerificationStatus.Pending,
    ): Engineer = Engineer(
        id = "engineer-1",
        userId = "user-1",
        aadhaarNumber = null,
        aadhaarVerified = false,
        qualifications = emptyList(),
        specializations = emptyList(),
        brandsServiced = emptyList(),
        experienceYears = 0,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = verificationStatus,
        backgroundCheckStatus = VerificationStatus.Pending,
        certificates = certificates,
    )

    private fun newViewModel(
        engineerRepo: EngineerRepository = mockk(relaxed = true) {
            coEvery { fetchByUserId(any()) } returns Result.success(engineer())
            coEvery { fetchMySuspension() } returns Result.success(null)
            // Uploaders return a deterministic path based on filename so
            // tests can assert "aadhaar-…" / "cert-…" prefixes downstream.
            coEvery { uploadKycDoc(any(), any(), any(), any()) } answers {
                val fileName = secondArg<String>()
                Result.success("user-1/$fileName")
            }
        },
        profileRepo: ProfileRepository = mockk(relaxed = true) {
            coEvery { fetchById(any()) } returns Result.success(null)
        },
        integrity: IntegrityVerifier = mockk {
            coEvery { requestVerification(any()) } returns Result.success(true)
        },
    ): Pair<KycViewModel, EngineerRepository> {
        val authRepo = mockk<AuthRepository>(relaxed = true) {
            every { sessionState } returns signedInSession
        }
        val photoStash = mockk<PhotoUploadStash>(relaxed = true)
        val locationFetcher = mockk<LocationFetcher>(relaxed = true)
        val userPrefs = mockk<UserPrefs>(relaxed = true)
        val storageRepo = mockk<StorageRepository>(relaxed = true)
        val savedState = SavedStateHandle()
        val vm = KycViewModel(
            authRepository = authRepo,
            engineerRepository = engineerRepo,
            profileRepository = profileRepo,
            photoUploadStash = photoStash,
            playIntegrityClient = integrity,
            locationFetcher = locationFetcher,
            userPrefs = userPrefs,
            storageRepository = storageRepo,
            savedStateHandle = savedState,
        )
        return vm to engineerRepo
    }

    // KycViewModel.effects is a MutableSharedFlow(replay=0, extraBufferCapacity=4)
    // — new collectors don't see past emissions, only future ones. Tests
    // must subscribe BEFORE the action that triggers the emit; otherwise
    // collection hangs forever. Use awaitNextEffect() pattern: launch a
    // collector, then perform the action, then await.
    private fun TestScope.captureNextEffect(vm: KycViewModel) =
        async(start = CoroutineStart.UNDISPATCHED) {
            vm.effects.first { it is KycViewModel.Effect.ShowMessage } as KycViewModel.Effect.ShowMessage
        }

    // ---------------------------------------------------------------------
    //  Tests
    // ---------------------------------------------------------------------

    @Test fun `save rejects when aadhaar number is present but not 12 digits`() = runTest {
        val (vm, _) = newViewModel()
        // Wait for load() to populate userId; without this the save() call
        // returns immediately on a null uid and no effect fires.
        vm.state.first { !it.loading }
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)
        vm.onAadhaarNumberChange("12345")

        val effect = captureNextEffect(vm)
        vm.save()

        assertEquals("Aadhaar must be 12 digits", effect.await().text)
    }

    @Test fun `save persists certificates with TYPE_AADHAAR and TYPE_CERT discriminator`() = runTest {
        // Capture the certificates argument the viewmodel passes to upsert.
        val certsSlot = slot<List<EngineerCertificate>>()
        val engineerRepo = mockk<EngineerRepository>(relaxed = true) {
            coEvery { fetchByUserId(any()) } returns Result.success(engineer())
            coEvery { fetchMySuspension() } returns Result.success(null)
            coEvery { uploadKycDoc(any(), any(), any(), any()) } answers {
                val fileName = secondArg<String>()
                Result.success("user-1/$fileName")
            }
            coEvery {
                upsert(
                    userId = any(),
                    aadhaarNumber = any(),
                    panNumber = any(),
                    qualifications = any(),
                    specializations = any(),
                    experienceYears = any(),
                    serviceRadiusKm = any(),
                    city = any(),
                    state = any(),
                    latitude = any(),
                    longitude = any(),
                    certificates = capture(certsSlot),
                    aadhaarUploaded = any(),
                    resetVerificationToPending = any(),
                )
            } returns Result.success(engineer(verificationStatus = VerificationStatus.Pending))
        }
        val (vm, _) = newViewModel(engineerRepo = engineerRepo)
        vm.state.first { !it.loading }
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)
        // Seed the doc paths directly into state by invoking the uploaders.
        // Stubbed uploadKycDoc returns "user-1/aadhaar-<ts>-scan.jpg" etc;
        // the viewmodel writes that storage path into UiState.
        vm.uploadAadhaarDoc("scan.jpg", ByteArray(8), "image/jpeg")
        vm.uploadCertificate("c1.pdf", ByteArray(8), "application/pdf")
        // Allow the upload coroutines to settle so aadhaarDocPath /
        // certDocPaths are populated before save() reads state.
        vm.state.first { it.aadhaarDocPath != null && it.certDocPaths.isNotEmpty() }

        vm.save()

        // Wait for save's launch to flush.
        vm.state.first { !it.saving }
        val saved = certsSlot.captured
        assertEquals(2, saved.size)
        assertEquals(EngineerCertificate.TYPE_AADHAAR, saved[0].type)
        assertTrue("aadhaar path should contain 'aadhaar-': ${saved[0].path}", saved[0].path.contains("aadhaar-"))
        assertEquals(EngineerCertificate.TYPE_CERT, saved[1].type)
        assertTrue("cert path should contain 'cert-': ${saved[1].path}", saved[1].path.contains("cert-"))
    }

    @Test fun `hydrate splits server certificates into aadhaar and cert slots`() = runTest {
        val seeded = engineer(
            certificates = listOf(
                EngineerCertificate(EngineerCertificate.TYPE_AADHAAR, "user-1/aadhaar-x.jpg", "t1"),
                EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-a.pdf", "t2"),
                EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-b.pdf", "t3"),
            ),
        )
        val engineerRepo = mockk<EngineerRepository>(relaxed = true) {
            coEvery { fetchByUserId(any()) } returns Result.success(seeded)
            coEvery { fetchMySuspension() } returns Result.success(null)
        }
        val (vm, _) = newViewModel(engineerRepo = engineerRepo)

        val state = vm.state.first { !it.loading }

        assertEquals("user-1/aadhaar-x.jpg", state.aadhaarDocPath)
        assertEquals(listOf("user-1/cert-a.pdf", "user-1/cert-b.pdf"), state.certDocPaths)
    }

    @Test fun `save surfaces repository failure as user message`() = runTest {
        val engineerRepo = mockk<EngineerRepository>(relaxed = true) {
            coEvery { fetchByUserId(any()) } returns Result.success(engineer())
            coEvery { fetchMySuspension() } returns Result.success(null)
            coEvery { uploadKycDoc(any(), any(), any(), any()) } answers {
                val fileName = secondArg<String>()
                Result.success("user-1/$fileName")
            }
            coEvery {
                upsert(
                    userId = any(),
                    aadhaarNumber = any(),
                    panNumber = any(),
                    qualifications = any(),
                    specializations = any(),
                    experienceYears = any(),
                    serviceRadiusKm = any(),
                    city = any(),
                    state = any(),
                    latitude = any(),
                    longitude = any(),
                    certificates = any(),
                    aadhaarUploaded = any(),
                    resetVerificationToPending = any(),
                )
            } returns Result.failure(RuntimeException("boom"))
        }
        val (vm, _) = newViewModel(engineerRepo = engineerRepo)
        vm.state.first { !it.loading }
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)

        val effect = captureNextEffect(vm)
        vm.save()
        val msg = effect.await().text
        assertTrue("expected non-blank failure message, got: '$msg'", msg.isNotBlank())
        // The exact wording goes through toUserMessage() so we assert
        // shape, not literal string.
    }
}
