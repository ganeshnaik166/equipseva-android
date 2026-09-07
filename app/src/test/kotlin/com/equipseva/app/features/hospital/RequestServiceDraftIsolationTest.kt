package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.sampleRequestDraft
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.features.hospital.RequestServiceViewModel.PhotoOperation
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RequestServiceDraftIsolationTest {
    private val viewModels = mutableListOf<RequestServiceViewModel>()
    @Before fun setup() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun teardown() {
        viewModels.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private fun profile() = mockk<Profile> {
        every { organizationId } returns "org-A"
        every { phone } returns "+919999999999"
        every { state } returns "Telangana"
        every { district } returns "Hyderabad"
    }

    private fun vm(
        fixture: DraftStoreFixture,
        handle: SavedStateHandle = SavedStateHandle(),
        profileRepo: ProfileRepository = mockk {
            coEvery { fetchById(any()) } returns Result.success(profile())
        },
        jobRepo: RepairJobRepository = mockk(relaxed = true),
        storage: StorageRepository = mockk(relaxed = true),
        directory: EngineerDirectoryRepository = mockk(relaxed = true),
    ) = RequestServiceViewModel(
        profileRepository = profileRepo,
        jobRepository = jobRepo,
        storageRepository = storage,
        savedStateHandle = handle,
        draftStore = fixture.store,
        engineerDirectoryRepository = directory,
        analytics = mockk(relaxed = true),
        crashReporter = mockk(relaxed = true),
    ).also { viewModels += it }

    @Test fun `foreign and ownerless saved handles never render private draft fields`() = runTest {
        val fixture = DraftStoreFixture(this)
        for (owner in listOf(null, "B")) {
            val handle = SavedStateHandle(mapOf(
                "req.ownerId" to owner, "req.sessionId" to "session-A",
                "req.issue" to "Private issue from another account",
                "req.siteAddress" to "Private site", "req.photos" to arrayOf("B/private.jpg"),
            ))
            val model = vm(fixture, handle)
            assertEquals("", model.state.value.issue)
            runCurrent()
            assertEquals("", model.state.value.issue)
            assertTrue(model.state.value.photos.isEmpty())
            assertNotEquals("Private site", model.state.value.siteAddress)
        }
    }

    @Test fun `same session saved handle restores immediately after identity resolves`() = runTest {
        val fixture = DraftStoreFixture(this)
        val handle = SavedStateHandle(mapOf(
            "req.ownerId" to "A", "req.sessionId" to "session-A",
            "req.issue" to "Unsent detailed issue", "req.siteAddress" to "Original address",
            "req.selectedSlot" to 2,
        ))
        val model = vm(fixture, handle)
        assertEquals("", model.state.value.issue)
        runCurrent()
        assertEquals("Unsent detailed issue", model.state.value.issue)
        assertEquals("Original address", model.state.value.siteAddress)
        assertEquals(2, model.state.value.selectedSlot)
        assertFalse(model.state.value.showDraftRecoveryBar)
    }

    @Test fun `fresh login of same owner cannot restore old session saved handle`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.signIn("A", "new-session-A")
        runCurrent()
        val model = vm(fixture, SavedStateHandle(mapOf(
            "req.ownerId" to "A", "req.sessionId" to "session-A", "req.issue" to "Old login issue",
        )))
        runCurrent()
        assertEquals("", model.state.value.issue)
    }

    @Test fun `account replacement clears old form and late field events cannot repopulate it`() = runTest {
        val fixture = DraftStoreFixture(this)
        val handle = SavedStateHandle()
        val model = vm(fixture, handle)
        runCurrent()
        model.onIssueChange("A's entered private issue")
        model.onSelectedSlotChange(2)
        val renderedSession = model.state.value.formSession
        fixture.signIn("B", "session-B")
        runCurrent()
        model.forFormSession(renderedSession) {
            onIssueChange("late text event from A")
            onSiteCoordsChange(17.0, 78.0)
            onSelectedSlotChange(4)
        }
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals("", model.state.value.issue)
        assertFalse(handle.contains("req.issue"))
        assertEquals("B", handle.get<String>("req.ownerId"))
        assertEquals(-1, model.state.value.selectedSlot)
        assertNull(fixture.store.loadDraft(fixture.lease()))
        model.forFormSession(model.state.value.formSession) { onIssueChange("B's new editable form") }
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals("B's new editable form", fixture.store.loadDraft(fixture.lease())?.issue)
    }

    @Test fun `slow initial recovery and undecided recovery bar preserve the existing draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        val saved = sampleRequestDraft("Saved original issue")
        fixture.store.saveDraft(fixture.lease(), saved)
        val release = CompletableDeferred<Unit>()
        fixture.disk.readGate = release
        val model = vm(fixture)
        runCurrent()
        assertTrue(model.state.value.checkingDraftRecovery)
        model.onIssueChange("New partial typing while disk is slow")
        advanceTimeBy(15_000)
        runCurrent()
        fixture.disk.readGate = null
        release.complete(Unit)
        runCurrent()
        assertTrue(model.state.value.showDraftRecoveryBar)
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals(saved, fixture.store.loadDraft(fixture.lease()))
        model.onKeepDraft()
        runCurrent()
        assertEquals(saved.issue, model.state.value.issue)
        assertFalse(model.state.value.showDraftRecoveryBar)
    }

    @Test fun `surviving viewmodel rebinds after missed signed out boundary without accepting old callbacks`() = runTest {
        val fixture = DraftStoreFixture(this)
        val handle = SavedStateHandle()
        val model = vm(fixture, handle)
        runCurrent()
        val renderedSession = model.state.value.formSession
        model.onIssueChange("A's old unsaved private issue")
        model.onSelectedSlotChange(1)
        fixture.identity = null
        fixture.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        assertNull(model.state.value.formSession)
        fixture.signIn("A", "session-A")
        runCurrent()
        assertNotSame(renderedSession, model.state.value.formSession)
        assertEquals("", model.state.value.issue)
        assertEquals(-1, model.state.value.selectedSlot)
        model.forFormSession(renderedSession) { onIssueChange("late old-session text") }
        assertEquals("", model.state.value.issue)
        model.forFormSession(model.state.value.formSession) { onIssueChange("Fresh A form remains usable") }
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals("Fresh A form remains usable", fixture.store.loadDraft(fixture.lease())?.issue)
    }

    @Test fun `picker result captured before switch cannot start upload on rebound form`() = runTest {
        val fixture = DraftStoreFixture(this)
        val storage = mockk<StorageRepository>(relaxed = true)
        val model = vm(fixture, storage = storage)
        runCurrent()
        val pickerLaunchSession = model.state.value.formSession
        fixture.signIn("B", "session-B")
        runCurrent()
        // Same boundary used by camera permission, camera result, gallery IO
        // completion, map and date callbacks in RequestServiceScreen.
        model.forFormSession(pickerLaunchSession) {
            onPhotoPicked("A-private.jpg", byteArrayOf(1), "image/jpeg")
            onPickedDateChange(1000L)
            onSiteCoordsChange(17.0, 78.0)
        }
        runCurrent()
        coVerify(exactly = 0) { storage.upload(any(), any(), any(), any()) }
        assertTrue(model.state.value.photos.isEmpty())
        assertNull(model.state.value.pickedDateMillis)
        assertNull(model.state.value.siteLatitude)
        assertEquals("B", model.state.value.formSession?.identity?.ownerId)
    }

    @Test fun `initial disk failure exposes retry without overwriting an unchecked draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        val saved = sampleRequestDraft("Unchecked original draft")
        fixture.store.saveDraft(fixture.lease(), saved)
        fixture.disk.nextReadFailure = IOException("read failed")
        val model = vm(fixture)
        runCurrent()
        assertFalse(model.state.value.checkingDraftRecovery)
        assertEquals(RequestServiceViewModel.DraftFailure.Check, model.state.value.draftFailure)
        model.onIssueChange("Partial new typing during read failure")
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals(saved, fixture.store.loadDraft(fixture.lease()))
        model.onRetryDraftOperation()
        runCurrent()
        assertNull(model.state.value.draftFailure)
        assertTrue(model.state.value.showDraftRecoveryBar)
        model.onKeepDraft()
        runCurrent()
        assertEquals(saved.issue, model.state.value.issue)
    }

    @Test fun `restored picker result waits while auth is genuinely unresolved`() = runTest {
        val fixture = DraftStoreFixture(this)
        for (kind in PhotoOperation.entries) {
            val handle = SavedStateHandle()
            val first = vm(fixture, handle)
            runCurrent()
            assertTrue(first.launchPhotoOperation(first.state.value.formSession, kind) {})
            first.viewModelScope.cancel()
            // Model SDK startup without a loaded session before restoring the VM.
            fixture.identity = null
            fixture.auth.setSession(AuthSession.SignedOut)
            runCurrent()
            fixture.auth.setSession(AuthSession.Unknown)
            runCurrent()
            assertNull(fixture.store.activeSession.value)
            val recreated = vm(fixture, handle)
            var deliveries = 0
            recreated.onPhotoOperationResult(kind) { lease ->
                assertSame(fixture.lease(), lease)
                deliveries++
            }
            runCurrent()
            assertNull(recreated.state.value.formSession)
            assertEquals(0, deliveries)
            assertTrue(handle.contains("reqPhoto.id"))
            fixture.signIn("A", "session-A")
            runCurrent()
            assertEquals(1, deliveries)
            assertFalse(handle.contains("reqPhoto.id"))
            recreated.onPhotoOperationResult(kind) { deliveries++ }
            runCurrent()
            assertEquals(1, deliveries)
            recreated.viewModelScope.cancel()
        }
    }

    @Test fun `pending camera gallery and permission results survive recreation before auth bind`() = runTest {
        val fixture = DraftStoreFixture(this)
        for (kind in PhotoOperation.entries) {
            val handle = SavedStateHandle()
            val first = vm(fixture, handle)
            runCurrent()
            assertTrue(first.launchPhotoOperation(first.state.value.formSession, kind) {})
            val operationId = handle.get<String>("reqPhoto.id")
            assertNotNull(operationId)
            first.viewModelScope.cancel()
            val recreated = vm(fixture, handle)
            var deliveries = 0
            // Restored ActivityResult is allowed to arrive before the new VM
            // has processed its initial authenticated identity.
            recreated.onPhotoOperationResult(kind) { lease ->
                assertSame(fixture.lease(), lease)
                deliveries++
            }
            assertEquals(0, deliveries)
            runCurrent()
            assertEquals(1, deliveries)
            assertFalse(handle.contains("reqPhoto.id"))
            recreated.onPhotoOperationResult(kind) { deliveries++ }
            runCurrent()
            assertEquals(1, deliveries)
            recreated.viewModelScope.cancel()
        }
    }

    @Test fun `old external result blocks replacement launch until drained then B may launch safely`() = runTest {
        val fixture = DraftStoreFixture(this)
        for (kind in PhotoOperation.entries) {
            fixture.signIn("A", "session-A")
            runCurrent()
            val handle = SavedStateHandle()
            val model = vm(fixture, handle)
            runCurrent()
            assertTrue(model.launchPhotoOperation(model.state.value.formSession, kind) {})
            val operationA = handle.get<String>("reqPhoto.id")
            fixture.signIn("B", "session-B")
            runCurrent()
            assertFalse(model.launchPhotoOperation(model.state.value.formSession, kind) { fail("B launched before A result drained") })
            assertEquals(operationA, handle.get<String>("reqPhoto.id"))
            model.onPhotoOperationResult(kind) { fail("A result was relabeled as B") }
            runCurrent()
            assertTrue(model.launchPhotoOperation(model.state.value.formSession, kind) {})
            assertNotEquals(operationA, handle.get<String>("reqPhoto.id"))
            var deliveries = 0
            model.onPhotoOperationResult(kind) { lease ->
                assertEquals("B", lease.identity.ownerId)
                deliveries++
            }
            runCurrent()
            assertEquals(1, deliveries)
            model.viewModelScope.cancel()
        }
    }

    @Test fun `foreign process restored photo result is drained without acquiring new owner`() = runTest {
        val fixture = DraftStoreFixture(this)
        val handle = SavedStateHandle()
        val first = vm(fixture, handle)
        runCurrent()
        first.launchPhotoOperation(first.state.value.formSession, PhotoOperation.Gallery) {}
        first.viewModelScope.cancel()
        fixture.signIn("B", "session-B")
        runCurrent()
        val recreated = vm(fixture, handle)
        runCurrent()
        assertFalse(recreated.launchPhotoOperation(recreated.state.value.formSession, PhotoOperation.Gallery) {})
        recreated.onPhotoOperationResult(PhotoOperation.Gallery) { fail("Restored A photo reached B") }
        runCurrent()
        assertTrue(recreated.launchPhotoOperation(recreated.state.value.formSession, PhotoOperation.Gallery) {})
    }

    @Test fun `same owner pending result stays invalid after auth boundary and process recreation`() = runTest {
        val fixture = DraftStoreFixture(this)
        val handle = SavedStateHandle()
        val first = vm(fixture, handle)
        runCurrent()
        first.launchPhotoOperation(first.state.value.formSession, PhotoOperation.Camera) {}
        fixture.identity = null
        fixture.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        fixture.signIn("A", "session-A")
        runCurrent()
        assertTrue(handle.get<Boolean>("reqPhoto.invalidated") == true)
        first.viewModelScope.cancel()
        val recreated = vm(fixture, handle)
        recreated.onPhotoOperationResult(PhotoOperation.Camera) { fail("Old photo lease revived") }
        runCurrent()
        assertFalse(handle.contains("reqPhoto.id"))
        assertTrue(recreated.launchPhotoOperation(recreated.state.value.formSession, PhotoOperation.Camera) {})
    }

    @Test fun `unsupported session claim asks to pick photo again after process recreation`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.signIn("A", null)
        runCurrent()
        val handle = SavedStateHandle()
        val first = vm(fixture, handle)
        runCurrent()
        first.launchPhotoOperation(first.state.value.formSession, PhotoOperation.Gallery) {}
        first.viewModelScope.cancel()
        val recreated = vm(fixture, handle)
        val effects = mutableListOf<RequestServiceViewModel.Effect>()
        backgroundScope.launch { recreated.effects.collect { effects += it } }
        recreated.onPhotoOperationResult(PhotoOperation.Gallery) { fail("Unverifiable photo restored") }
        runCurrent()
        assertEquals(1, effects.count { it is RequestServiceViewModel.Effect.RetryPhotoSelection })
        assertTrue(recreated.launchPhotoOperation(recreated.state.value.formSession, PhotoOperation.Gallery) {})
    }

    @Test fun `failed keep preserves current form and supports retry of original draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        val saved = sampleRequestDraft("Draft to restore").copy(selectedSlot = 2)
        fixture.store.saveDraft(fixture.lease(), saved)
        val model = vm(fixture)
        runCurrent()
        model.onIssueChange("Current partial issue")
        fixture.disk.nextReadFailure = IOException("restore failed")
        model.onKeepDraft()
        runCurrent()
        assertEquals(RequestServiceViewModel.DraftFailure.Restore, model.state.value.draftFailure)
        assertFalse(model.state.value.checkingDraftRecovery)
        assertEquals("Current partial issue", model.state.value.issue)
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals(saved, fixture.store.loadDraft(fixture.lease()))
        model.onRetryDraftOperation()
        runCurrent()
        assertEquals(saved.issue, model.state.value.issue)
        assertEquals(2, model.state.value.selectedSlot)
        assertNull(model.state.value.draftFailure)
        assertFalse(model.state.value.showDraftRecoveryBar)
    }

    @Test fun `failed discard preserves disk bytes and current form until retry succeeds`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft("Original draft to delete"))
        val originalBytes = fixture.disk.value
        val model = vm(fixture)
        runCurrent()
        model.onIssueChange("New partial issue to retain")
        fixture.disk.nextWriteFailure = IOException("delete failed")
        model.onDiscardDraft()
        runCurrent()
        assertEquals(RequestServiceViewModel.DraftFailure.Discard, model.state.value.draftFailure)
        assertEquals("New partial issue to retain", model.state.value.issue)
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals(originalBytes, fixture.disk.value)
        model.onRetryDraftOperation()
        runCurrent()
        assertNull(model.state.value.draftFailure)
        assertFalse(model.state.value.showDraftRecoveryBar)
        assertEquals("New partial issue to retain", model.state.value.issue)
        assertTrue(fixture.disk.value.asMap().isEmpty())
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals("New partial issue to retain", fixture.store.loadDraft(fixture.lease())?.issue)
    }

    @Test fun `autosave failure is recoverable and does not terminate future saves`() = runTest {
        val fixture = DraftStoreFixture(this)
        val model = vm(fixture)
        runCurrent()
        fixture.disk.nextWriteFailure = IOException("save failed")
        model.onIssueChange("First detailed issue")
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals(RequestServiceViewModel.DraftFailure.Save, model.state.value.draftFailure)
        assertEquals("First detailed issue", model.state.value.issue)
        model.onRetryDraftOperation()
        runCurrent()
        assertNull(model.state.value.draftFailure)
        assertEquals("First detailed issue", fixture.store.loadDraft(fixture.lease())?.issue)
        model.onIssueChange("Later detailed issue after recovery")
        advanceTimeBy(10_001)
        runCurrent()
        assertEquals("Later detailed issue after recovery", fixture.store.loadDraft(fixture.lease())?.issue)
    }

    @Test fun `late restore and profile results cannot cross account replacement`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft())
        val profileResult = CompletableDeferred<Result<Profile?>>()
        val profileRepo = mockk<ProfileRepository> {
            coEvery { fetchById("A") } coAnswers { profileResult.await() }
            coEvery { fetchById("B") } returns Result.success(null)
        }
        val model = vm(fixture, profileRepo = profileRepo)
        runCurrent()
        val releaseRead = CompletableDeferred<Unit>()
        fixture.disk.readGate = releaseRead
        model.onKeepDraft()
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        fixture.disk.readGate = null
        releaseRead.complete(Unit)
        profileResult.complete(Result.success(profile()))
        runCurrent()
        assertEquals("", model.state.value.issue)
        assertEquals("", model.state.value.siteAddress)
        assertFalse(model.state.value.showDraftRecoveryBar)
    }

    @Test fun `recreation during initial disk lookup keeps autosave gated until recovery decision`() = runTest {
        val fixture = DraftStoreFixture(this)
        val saved = sampleRequestDraft("Original draft awaiting recovery")
        fixture.store.saveDraft(fixture.lease(), saved)
        val release = CompletableDeferred<Unit>()
        fixture.disk.readGate = release
        val handle = SavedStateHandle()
        val first = vm(fixture, handle)
        runCurrent()
        first.onIssueChange("Partial new typing")
        first.viewModelScope.cancel()
        val recreated = vm(fixture, handle)
        runCurrent()
        assertTrue(recreated.state.value.checkingDraftRecovery)
        advanceTimeBy(15_000)
        runCurrent()
        fixture.disk.readGate = null
        release.complete(Unit)
        runCurrent()
        assertTrue(recreated.state.value.showDraftRecoveryBar)
        assertEquals(saved, fixture.store.loadDraft(fixture.lease()))
    }

    @Test fun `recreation with visible recovery prompt preserves prompt and old draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        val saved = sampleRequestDraft("Original draft before recreation")
        fixture.store.saveDraft(fixture.lease(), saved)
        val handle = SavedStateHandle()
        val first = vm(fixture, handle)
        runCurrent()
        assertTrue(first.state.value.showDraftRecoveryBar)
        first.viewModelScope.cancel()
        val recreated = vm(fixture, handle)
        runCurrent()
        assertTrue(recreated.state.value.showDraftRecoveryBar)
        recreated.onIssueChange("Partial new issue while deciding")
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals(saved, fixture.store.loadDraft(fixture.lease()))
        recreated.onKeepDraft()
        runCurrent()
        assertEquals(saved.issue, recreated.state.value.issue)
        recreated.viewModelScope.cancel()
        val afterKeep = vm(fixture, handle)
        runCurrent()
        assertFalse(afterKeep.state.value.showDraftRecoveryBar)
        assertEquals(saved.issue, afterKeep.state.value.issue)
    }

    @Test fun `late photo upload cannot attach A photo to replacement account state`() = runTest {
        val fixture = DraftStoreFixture(this)
        val response = CompletableDeferred<Result<StorageRepository.UploadReceipt>>()
        val storage = mockk<StorageRepository> {
            coEvery { upload(any(), any(), any(), any()) } coAnswers { response.await() }
        }
        val handle = SavedStateHandle()
        val model = vm(fixture, handle, storage = storage)
        runCurrent()
        model.onPhotoPicked("sample.jpg", byteArrayOf(1), "image/jpeg")
        runCurrent()
        assertTrue(model.state.value.uploadingPhoto)
        fixture.signIn("B", "session-B")
        runCurrent()
        response.complete(Result.success(StorageRepository.UploadReceipt("repair-photos", "A/photo.jpg", "hash", 1)))
        runCurrent()
        assertTrue(model.state.value.photos.isEmpty())
        assertFalse(model.state.value.uploadingPhoto)
        assertFalse(handle.contains("req.photos"))
    }

    @Test fun `late engineer reassurance cannot populate replacement account form`() = runTest {
        val fixture = DraftStoreFixture(this)
        val response = CompletableDeferred<Result<EngineerDirectoryRepository.PublicProfile?>>()
        val directory = mockk<EngineerDirectoryRepository> {
            coEvery { fetchPublicProfile("engineer-1") } coAnswers { response.await() }
        }
        val handle = SavedStateHandle(mapOf("engineerId" to "engineer-1"))
        val model = vm(fixture, handle, directory = directory)
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        response.complete(Result.success(mockk(relaxed = true)))
        runCurrent()
        assertNull(model.state.value.prefilledEngineerId)
        assertNull(model.state.value.prefilledEngineerName)
        assertNull(model.state.value.prefilledEngineerRating)
        assertFalse(handle.contains("req.engineerId"))
    }

    @Test fun `late discard cannot clear replacement account draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft())
        val model = vm(fixture)
        runCurrent()
        val release = CompletableDeferred<Unit>()
        fixture.disk.nextWriteGate = release
        model.onDiscardDraft()
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        val saveB = launch { fixture.store.saveDraft(fixture.lease(), sampleRequestDraft("B's draft")) }
        runCurrent()
        release.complete(Unit)
        saveB.join()
        runCurrent()
        assertEquals("B's draft", fixture.store.loadDraft(fixture.lease())?.issue)
    }

    @Test fun `late successful submission cannot clear B draft or navigate B`() = runTest {
        val fixture = DraftStoreFixture(this)
        val response = CompletableDeferred<Result<RepairJob>>()
        val jobs = mockk<RepairJobRepository> { coEvery { create(any()) } coAnswers { response.await() } }
        val model = vm(fixture, jobRepo = jobs)
        val effects = mutableListOf<RequestServiceViewModel.Effect>()
        backgroundScope.launch { model.effects.collect { effects += it } }
        runCurrent()
        model.onIssueChange("A's valid service request")
        model.onSubmit(3)
        runCurrent()
        coVerify(exactly = 1) { jobs.create(any()) }
        fixture.signIn("B", "session-B")
        runCurrent()
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft("B's own draft"))
        response.complete(Result.success(mockk(relaxed = true)))
        runCurrent()
        assertEquals("B's own draft", fixture.store.loadDraft(fixture.lease())?.issue)
        assertTrue(effects.none { it is RequestServiceViewModel.Effect.Submitted })
        assertEquals("", model.state.value.issue)
    }

    @Test fun `completed submission cannot be recreated by autosave waiting on disk`() = runTest {
        val fixture = DraftStoreFixture(this)
        val jobs = mockk<RepairJobRepository> {
            coEvery { create(any()) } returns Result.success(mockk(relaxed = true))
        }
        val model = vm(fixture, jobRepo = jobs)
        runCurrent()
        val release = CompletableDeferred<Unit>()
        fixture.disk.nextWriteGate = release
        model.onIssueChange("A valid request being submitted")
        advanceTimeBy(10_001)
        runCurrent()
        model.onSubmit(3)
        runCurrent()
        release.complete(Unit)
        runCurrent()
        advanceTimeBy(15_000)
        runCurrent()
        assertEquals("", model.state.value.issue)
        assertNull(fixture.store.loadDraft(fixture.lease()))
    }

    @Test fun `missing stable session claim permits new service submission without persistence`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.signIn("A", null)
        runCurrent()
        val jobs = mockk<RepairJobRepository> {
            coEvery { create(any()) } returns Result.success(mockk(relaxed = true))
        }
        val model = vm(fixture, jobRepo = jobs)
        runCurrent()
        model.onIssueChange("New request without recoverable session claim")
        model.onSubmit(3)
        runCurrent()
        coVerify(exactly = 1) { jobs.create(any()) }
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `server confirmed submission survives failed local cleanup and suppresses stale recovery`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft("Pre-submission persistent draft"))
        val jobs = mockk<RepairJobRepository> {
            coEvery { create(any()) } returns Result.success(mockk(relaxed = true))
        }
        val model = vm(fixture, jobRepo = jobs)
        val effects = mutableListOf<RequestServiceViewModel.Effect>()
        backgroundScope.launch { model.effects.collect { effects += it } }
        runCurrent()
        model.onKeepDraft()
        runCurrent()
        fixture.disk.nextWriteFailure = IOException("disk write failed")
        model.onSubmit(3)
        runCurrent()
        coVerify(exactly = 1) { jobs.create(any()) }
        assertEquals(1, effects.count { it is RequestServiceViewModel.Effect.Submitted })
        assertEquals("", model.state.value.issue)
        // A later successful read retries cleanup; it never restores the cleared epoch.
        assertNull(fixture.store.loadDraft(fixture.lease()))
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }
}
