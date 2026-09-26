package com.equipseva.app.features.repair

import android.app.Application
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.CostRevisionRepository
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.core.util.fetchCurrentLocation
import com.equipseva.app.navigation.Routes
import com.equipseva.app.testing.AuthAuditFixtures
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.FakeRest
import com.equipseva.app.features.auth.UserRole
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * Drives the REAL [RepairJobDetailViewModel] over the "queued — will
 * send when back online" paths.
 *
 * The regression being locked down: every write failure on this screen
 * used to be treated as an outage. A server refusal was enqueued to an
 * outbox that drops 4xx rows permanently, the local job status was
 * optimistically flipped to the rejected target, and the user was told
 * the change would apply when back online. The write never happened,
 * the screen said it had, and nothing ever corrected either.
 *
 * Vacuity guards: each test asserts the post-load state (job loaded,
 * Engineer role, engineer row id resolved, idle flags) before acting,
 * because this viewmodel has several silent gates — job not loaded,
 * viewer not Engineer, wrong status, blank uid — any of which would
 * make "no enqueue happened" true for the wrong reason.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RepairJobDetailOfflinePromiseTest {

    private val jobId = "11111111-1111-1111-1111-111111111111"
    private val uid = "22222222-2222-2222-2222-222222222222"
    private val hospitalUid = "33333333-3333-3333-3333-333333333333"

    // Built at construction time, not inside a test coroutine: the
    // helper spins a real ktor MockEngine through runBlocking to get a
    // faithful RestException (the SDK derives statusCode and the
    // URL/headers diagnostics in `message` from a real response).
    private val transitionRefusal =
        FakeRest.rest(422, "invalid status transition in_progress -> completed")
    private val bidRefusal =
        FakeRest.rest(403, "new row violates row-level security policy")

    private val jobRepository = mockk<RepairJobRepository>()
    private val bidRepository = mockk<RepairBidRepository>()
    private val outboxEnqueuer = mockk<OutboxEnqueuer>(relaxed = true)
    private val stash = mockk<PhotoUploadStash>()
    private lateinit var vm: RepairJobDetailViewModel

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @After fun tearDown() {
        if (::vm.isInitialized) vm.viewModelScope.cancel()
        Dispatchers.resetMain()
        unmockkAll()
    }

    // ---- status transitions -------------------------------------------

    @Test fun `a server refusal on Mark done is NOT queued and does not flip the local status`() = runTest {
        val refusal = transitionRefusal
        coEvery { jobRepository.updateStatus(any(), any(), any(), any(), any()) } returns
            Result.failure(refusal)
        build(job(RepairJobStatus.InProgress))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.InProgress)
        val messages = collectMessages()

        vm.markDone()
        runCurrent()

        coVerify(exactly = 1) { jobRepository.updateStatus(any(), any(), any(), any(), any()) }
        // The outbox would GiveUp on this 4xx, so enqueueing it is a
        // promise the app cannot keep.
        coVerify(exactly = 0) { outboxEnqueuer.enqueue(any(), any()) }
        assertEquals(
            "local status must not advance past what the server accepted",
            RepairJobStatus.InProgress,
            vm.state.value.job?.status,
        )
        assertFalse(vm.state.value.updatingStatus)
        assertEquals(1, messages.size)
        assertEquals(refusal.toUserMessage(), messages.single())
        assertFalse(
            "a refusal must not read as an outage, got: ${messages.single()}",
            messages.single().contains("Offline", ignoreCase = true),
        )
    }

    @Test fun `a real outage on Mark done IS queued with the offline promise`() = runTest {
        coEvery { jobRepository.updateStatus(any(), any(), any(), any(), any()) } returns
            Result.failure(IOException("no route to host"))
        build(job(RepairJobStatus.InProgress))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.InProgress)
        val messages = collectMessages()

        vm.markDone()
        runCurrent()

        // The other half of the pin: the offline path must keep working,
        // optimistic flip included, or an engineer in a basement stops
        // being able to close jobs at all.
        coVerify(exactly = 1) { outboxEnqueuer.enqueue(any(), any()) }
        assertEquals(RepairJobStatus.Completed, vm.state.value.job?.status)
        assertEquals(1, messages.size)
        assertTrue("got: ${messages.single()}", messages.single().contains("Offline"))
    }

    // ---- bids ----------------------------------------------------------

    @Test fun `a refused bid is NOT queued and the composer keeps the typed values`() = runTest {
        val refusal = bidRefusal
        coEvery { bidRepository.placeBid(any(), any(), any(), any()) } returns Result.failure(refusal)
        build(job(RepairJobStatus.Requested))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.Requested)
        val messages = collectMessages()

        vm.openBidComposer()
        vm.submitBid(amountRupees = 2500.0, etaHours = 4, note = "Can be there by noon")
        runCurrent()

        coVerify(exactly = 1) { bidRepository.placeBid(any(), any(), any(), any()) }
        coVerify(exactly = 0) { outboxEnqueuer.enqueue(any(), any()) }
        assertTrue(
            "the composer must stay open on a refusal — it holds the only copy of the typed bid",
            vm.state.value.bidComposerOpen,
        )
        assertFalse(vm.state.value.placingBid)
        assertEquals(refusal.toUserMessage(), messages.single())
    }

    @Test fun `a bid that failed on the network IS queued and the composer closes`() = runTest {
        coEvery { bidRepository.placeBid(any(), any(), any(), any()) } returns
            Result.failure(IOException("connection reset"))
        build(job(RepairJobStatus.Requested))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.Requested)
        val messages = collectMessages()

        vm.openBidComposer()
        vm.submitBid(amountRupees = 2500.0, etaHours = 4, note = null)
        runCurrent()

        coVerify(exactly = 1) { outboxEnqueuer.enqueue(any(), any()) }
        assertFalse(vm.state.value.bidComposerOpen)
        assertTrue("got: ${messages.single()}", messages.single().contains("Offline"))
    }

    // ---- photo evidence ------------------------------------------------

    @Test fun `a job cannot be completed when no after-photo reached the stash`() = runTest {
        // The stash rejects oversized files; a 50 MP camera JPEG clears
        // its cap. Completing anyway is unrecoverable — escrow
        // auto-releases 48h later with nothing to dispute against.
        coEvery { stash.enqueue(any(), any(), any(), any(), any(), any(), any()) } throws
            IllegalArgumentException("file too large")
        coEvery { jobRepository.updateStatus(any(), any(), any(), any(), any()) } returns
            Result.success(job(RepairJobStatus.Completed))
        build(job(RepairJobStatus.InProgress))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.InProgress)
        val messages = collectMessages()

        vm.openProofSheet()
        assertTrue("vacuity guard: the proof sheet must actually be open", vm.state.value.proofSheetOpen)
        vm.submitCompletionProof(listOf(photo("after.jpg")))
        runCurrent()

        coVerify(exactly = 0) { jobRepository.updateStatus(any(), any(), any(), any(), any()) }
        assertEquals(RepairJobStatus.InProgress, vm.state.value.job?.status)
        assertTrue("the sheet must stay open so the engineer can retry", vm.state.value.proofSheetOpen)
        assertFalse(vm.state.value.submittingProof)
        assertEquals(1, messages.size)
        assertTrue("got: ${messages.single()}", messages.single().contains("smaller"))
    }

    @Test fun `a second check-in tap during the photo read cannot stash the set twice`() = runTest {
        mockkStatic("com.equipseva.app.core.util.CurrentLocationKt")
        coEvery { fetchCurrentLocation(any(), any()) } returns null
        coEvery { stash.enqueue(any(), any(), any(), any(), any(), any(), any()) } returns Unit
        build(job(RepairJobStatus.Assigned))
        runCurrent()
        assertLoadedAsEngineer(RepairJobStatus.Assigned)

        val photos = listOf(photo("before-1.jpg"), photo("before-2.jpg"))
        // Back-to-back, with no dispatcher turn between them: the flag
        // has to be claimed synchronously or the second call re-enters
        // the whole path and stashes (and later uploads) the same
        // before-photo set again.
        vm.submitCheckinWithProof(photos)
        vm.submitCheckinWithProof(photos)
        runCurrent()

        coVerify(exactly = photos.size) {
            stash.enqueue(any(), any(), any(), any(), any(), any(), any())
        }
        coVerify(exactly = 1) { fetchCurrentLocation(any(), any()) }
        assertFalse(vm.state.value.updatingStatus)
    }

    // ---- harness -------------------------------------------------------

    /**
     * Subscribes to the message flow, which has no replay — a collector
     * attached after the action would see nothing and every "exactly one
     * message" assertion would pass vacuously.
     */
    private fun kotlinx.coroutines.test.TestScope.collectMessages(): List<String> {
        val messages = mutableListOf<String>()
        backgroundScope.launch { vm.messages.collect { messages += it } }
        runCurrent()
        return messages
    }

    private fun assertLoadedAsEngineer(status: RepairJobStatus) {
        val s = vm.state.value
        assertFalse("load() must have finished", s.loading)
        assertEquals(status, s.job?.status)
        assertEquals(RepairJobDetailViewModel.ViewerRole.Engineer, s.viewerRole)
        assertEquals(ENGINEER_ROW_ID, s.selfEngineerRowId)
        assertFalse(s.updatingStatus)
        assertFalse(s.placingBid)
    }

    private fun photo(name: String) = RepairJobDetailViewModel.CompletionProofPhoto(
        fileName = name,
        mimeType = "image/jpeg",
        bytes = byteArrayOf(1, 2, 3),
    )

    private fun job(status: RepairJobStatus) = RepairJob(
        id = jobId,
        jobNumber = "RPR-00040",
        title = "Monitor dead",
        issueDescription = "Monitor dead",
        equipmentCategory = RepairEquipmentCategory.PatientMonitoring,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = status != RepairJobStatus.Requested,
        engineerId = if (status == RepairJobStatus.Requested) null else ENGINEER_ROW_ID,
        // Must be non-null and differ from uid or the viewer resolves to
        // Hospital / Other and every action below silently no-ops.
        hospitalUserId = hospitalUid,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private fun engineerRow() = Engineer(
        id = ENGINEER_ROW_ID,
        userId = uid,
        aadhaarNumber = null,
        aadhaarVerified = true,
        qualifications = emptyList(),
        specializations = listOf(RepairEquipmentCategory.PatientMonitoring),
        brandsServiced = emptyList(),
        experienceYears = 5,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        // submitBid gates on this client-side before it ever calls the
        // repository; an unverified row would make the bid tests pass
        // without reaching placeBid at all.
        verificationStatus = VerificationStatus.Verified,
        backgroundCheckStatus = VerificationStatus.Verified,
        certificates = emptyList(),
    )

    /**
     * Every Result-returning call that load() / refreshEscrow() / the
     * action under test reaches is stubbed explicitly: a relaxed MockK
     * default for kotlin.Result is a broken value that blows up inside
     * getOrNull() / fold().
     */
    private fun build(job: RepairJob): RepairJobDetailViewModel {
        coEvery { jobRepository.fetchById(jobId) } returns Result.success(job)
        coEvery { bidRepository.fetchOwnBidForJob(jobId) } returns Result.success(null as RepairBid?)
        return RepairJobDetailViewModel(
            savedState = SavedStateHandle(mapOf(Routes.REPAIR_DETAIL_ARG_ID to jobId)),
            // Strict: only checkIn() -> fetchCurrentLocation(app) touches
            // it, and that top-level function is static-mocked.
            app = mockk<Application>(),
            jobRepository = jobRepository,
            bidRepository = bidRepository,
            chatRepository = mockk(relaxed = true),
            authRepository = FakeAuthRepository(AuthSession.SignedIn(uid, "engineer@test.invalid")),
            engineerRepository = mockk<EngineerRepository> {
                coEvery { fetchByUserId(uid) } returns Result.success(engineerRow())
            },
            // Only the hospital viewer's counterparty lookups reach it.
            engineerDirectoryRepository = mockk<EngineerDirectoryRepository>(relaxed = true),
            profileRepository = mockk<ProfileRepository> {
                // submitBid gates on the engineer having a phone before
                // it calls placeBid; without one the bid tests would
                // never reach the branch under test.
                coEvery { fetchById(any()) } returns Result.success(
                    AuthAuditFixtures.confirmedProfile(id = uid, role = UserRole.ENGINEER),
                )
            },
            userPrefs = mockk<UserPrefs> { every { activeRole } returns flowOf("engineer") },
            outboxEnqueuer = outboxEnqueuer,
            outboxDao = mockk<OutboxDao> { every { observePendingCountByKind(any()) } returns flowOf(0) },
            reportRepository = mockk(relaxed = true),
            photoUploadStash = stash,
            storageRepository = mockk(relaxed = true),
            costRevisionRepository = mockk<CostRevisionRepository> {
                every { observePending(jobId) } returns flowOf(null)
            },
            serviceReportRepository = mockk(relaxed = true),
            repairInvoiceRepository = mockk(relaxed = true),
            escrowRepository = mockk<RepairJobEscrowRepository> {
                coEvery { fetchByJob(jobId) } returns Result.success(null)
            },
            payoutRepository = mockk<EngineerPayoutRepository> {
                coEvery { fetchPayoutStatusForJob(jobId) } returns Result.success(null)
            },
            json = Json,
            analytics = mockk(relaxed = true),
            crashReporter = mockk(relaxed = true),
        ).also { vm = it }
    }

    private companion object {
        const val ENGINEER_ROW_ID = "eng-row-1"
    }
}
