package com.equipseva.app.features.hospital

import android.content.Context
import android.os.Bundle
import android.os.Parcel
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.moderation.UserBlockRepository
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RequestServiceDraftStore
import com.equipseva.app.core.data.repair.sampleRequestDraft
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.handlers.DefaultPhotoUploadStash
import com.equipseva.app.testing.FakeAuthRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.realtime.realtime
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * INT-01 of the frozen slice in docs/HANDOFF_CLAUDEDEV_HELP.md: one account switch driven end to
 * end through REAL components on a single JVM.
 *
 * Real:
 *  - an on-disk Preferences DataStore (PreferenceDataStoreFactory over a TemporaryFolder file, IO on
 *    Dispatchers.IO) — the bytes asserted here are the bytes a cold start would read back;
 *  - RequestServiceDraftStore via its internal constructor (the identity lambda stands in for the
 *    GoTrue session's owner id + session_id, flipped in lockstep with FakeAuthRepository);
 *  - RequestServiceViewModel over a real SavedStateHandle, including an android.os.Parcel round trip
 *    of its saved Bundle (Robolectric provides Bundle/Parcel);
 *  - SignOutCleanup.wipeLocalUserState(), hand-built: real RequestServiceDraftStore, real
 *    DefaultPhotoUploadStash (Robolectric filesDir), real UserBlockRepository.
 * Fake / no-op:
 *  - FakeAuthRepository (SignedIn / SignedOut / Unknown emissions);
 *  - relaxed mocks for DeviceTokenRegistrar, OutboxDao, OutboxScheduler, UserPrefs and the three
 *    pending-payment stores; a relaxed SupabaseClient whose `realtime` extension is statically mocked
 *    to a Realtime with no subscriptions;
 *  - mocked Profile / RepairJob / Storage repositories, gated with CompletableDeferred where a late
 *    callback is under test.
 *
 * What this adds over the existing suites: RequestServiceDraftStoreTest and
 * RequestServiceDraftPersistenceTest exercise the store alone (in-memory and on disk),
 * RequestServiceDraftIsolationTest exercises the ViewModel over an in-memory store, and
 * SignOutDraftFenceTest exercises SignOutCleanup over an in-memory store. None of them runs the single
 * flow disk -> store -> ViewModel -> SignOutCleanup -> next account, none parcels the saved state, and
 * none proves presence before absence. Here every "B never sees A" assertion is preceded by a
 * raw-preferences proof that A's owner id, session id and issue text were on disk, and every "late
 * callback lands nowhere" assertion is paired with a positive control in this class that lands the
 * same gated callback without a sign-out, plus a resumed-counter proving the gated continuation ran.
 *
 * Not proven here: real GoTrue tokens or session refresh (the identity lambda replaces the JWT parse;
 * see INT-02), Compose rendering, Hilt wiring, real Storage / PostgREST calls, and the
 * DeviceTokenRegistrar / Outbox / UserPrefs cleanups themselves (relaxed mocks).
 *
 * Time is virtual only (runCurrent / advanceTimeBy / advanceUntilIdle). Real disk IO is awaited by
 * suspending on the DataStore flow itself (dataStore.data.first { ... }), never by sleeping; runTest
 * resumes those waits when the IO thread dispatches back onto the test scheduler.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@OptIn(ExperimentalCoroutinesApi::class)
class RequestServiceAccountSwitchIntegrationTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    private val context: Context by lazy { ApplicationProvider.getApplicationContext() }
    private val diskScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var supabase: SupabaseClient
    private val viewModels = mutableListOf<RequestServiceViewModel>()

    private val auth = FakeAuthRepository(AuthSession.SignedIn("A", "a@test.invalid"))
    private var identity: RequestServiceDraftStore.Identity? = RequestServiceDraftStore.Identity("A", "session-A")
    private var now = 1_000_000L

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        mockkStatic("io.github.jan.supabase.realtime.RealtimeKt")
        supabase = mockk(relaxed = true)
        every { supabase.realtime } returns mockk<Realtime> { every { subscriptions } returns emptyMap() }
        // Exactly one live DataStore per file for the whole test.
        dataStore = PreferenceDataStoreFactory.create(
            scope = diskScope,
            produceFile = { File(temporaryFolder.root, "draft.preferences_pb") },
        )
    }

    @After fun tearDown() {
        viewModels.forEach { it.viewModelScope.cancel() }
        // The disk scope is normally closed inside the test body (see
        // [integrationTest]) where runTest keeps pumping the Main test
        // dispatcher. Out here nothing pumps it, so an unbounded join could
        // park Robolectric's main thread forever (observed once: 18 minutes).
        // This is only a bounded safety net for a test that failed early.
        diskScope.cancel()
        runBlocking { withTimeoutOrNull(5_000) { diskScope.coroutineContext[Job]?.join() } }
        unmockkStatic("io.github.jan.supabase.realtime.RealtimeKt")
        Dispatchers.resetMain()
    }

    /**
     * runTest plus an in-body close of the on-disk DataStore: cancel the disk
     * scope and join it WHILE the test scheduler is still advancing, so any
     * continuation the DataStore actor hands back to the Main test dispatcher
     * can complete. Mirrors RequestServiceDraftPersistenceTest's DiskStore.close().
     */
    private fun integrationTest(block: suspend TestScope.() -> Unit) = runTest {
        try {
            block()
        } finally {
            viewModels.forEach { it.viewModelScope.cancel() }
            diskScope.cancel()
            // Real-time bound: a DataStore child that ignores cancellation must
            // not convert a finished test into a 60 s UncompletedCoroutinesError.
            // Closing the file is best-effort; the assertions above are the test.
            withContext(Dispatchers.Default) {
                withTimeoutOrNull(REAL_WAIT_MS) { diskScope.coroutineContext[Job]?.join() }
            }
        }
    }

    // ---------------------------------------------------------------- fixtures

    private fun TestScope.newStore(): RequestServiceDraftStore = RequestServiceDraftStore(
        dataStore = dataStore,
        authRepository = auth,
        currentIdentity = { identity },
        scope = backgroundScope,
        nowMillis = { now },
    )

    private fun signIn(owner: String, session: String) {
        identity = RequestServiceDraftStore.Identity(owner, session)
        // Distinct email per login so the StateFlow-backed fake re-emits for a same-owner new login.
        auth.setSession(AuthSession.SignedIn(owner, "$session@test.invalid"))
    }

    private fun signOut() {
        identity = null
        auth.setSession(AuthSession.SignedOut)
    }

    private fun profile(profileState: String = "Telangana", profileDistrict: String = "Hyderabad") = mockk<Profile> {
        every { organizationId } returns "org-A"
        every { phone } returns "+919999999999"
        every { state } returns profileState
        every { district } returns profileDistrict
    }

    private fun repairJob(jobId: String, number: String?) = mockk<RepairJob> {
        every { id } returns jobId
        every { jobNumber } returns number
    }

    private fun vm(
        store: RequestServiceDraftStore,
        handle: SavedStateHandle = SavedStateHandle(),
        profileRepo: ProfileRepository = mockk {
            coEvery { fetchById(any()) } returns Result.success(profile())
        },
        jobRepo: RepairJobRepository = mockk(relaxed = true),
        storage: StorageRepository = mockk(relaxed = true),
    ): RequestServiceViewModel = RequestServiceViewModel(
        profileRepository = profileRepo,
        jobRepository = jobRepo,
        storageRepository = storage,
        savedStateHandle = handle,
        draftStore = store,
        engineerDirectoryRepository = mockk<EngineerDirectoryRepository>(relaxed = true),
        analytics = mockk(relaxed = true),
        crashReporter = mockk(relaxed = true),
    ).also { viewModels += it }

    /**
     * Waits for a REAL-IO-backed condition with a REAL-time bound. Inside
     * runTest, `withTimeout` on the test dispatcher would use virtual time and
     * fire instantly, so the wait hops to Dispatchers.Default where the clock is
     * real. A wait that does not resolve fails with the observed state instead
     * of hanging until runTest's 60 s UncompletedCoroutinesError (which is what
     * the first CI run of this class produced, with no diagnostic).
     */
    private suspend fun <T> awaitReal(what: String, observed: suspend () -> String, block: suspend () -> T): T =
        withContext(Dispatchers.Default) { withTimeoutOrNull(REAL_WAIT_MS) { block() } }
            ?: throw AssertionError("timed out after $REAL_WAIT_MS ms (real time) waiting for $what; observed: ${observed()}")

    /** Waits until [model]'s state satisfies [predicate] (real-time bounded). */
    private suspend fun awaitState(
        model: RequestServiceViewModel,
        what: String,
        predicate: (RequestServiceViewModel.UiState) -> Boolean,
    ): RequestServiceViewModel.UiState =
        awaitReal(what, { model.state.value.toString() }) { model.state.first { predicate(it) } }

    /** Runs the lease/bind collectors, then waits for the REAL disk recovery read to finish. */
    private suspend fun TestScope.bind(model: RequestServiceViewModel): RequestServiceViewModel {
        runCurrent()
        awaitState(model, "the initial disk recovery check to finish") { !it.checkingDraftRecovery }
        return model
    }

    private fun signOutCleanup(store: RequestServiceDraftStore) = SignOutCleanup(
        deviceTokenRegistrar = mockk(relaxed = true),
        outboxDao = mockk(relaxed = true),
        outboxScheduler = mockk(relaxed = true),
        photoUploadStash = DefaultPhotoUploadStash(context, mockk<OutboxEnqueuer>(relaxed = true), Json),
        userPrefs = mockk(relaxed = true),
        userBlockRepository = UserBlockRepository(supabase),
        supabaseClient = supabase,
        pendingEscrowPaymentsStore = mockk(relaxed = true),
        pendingAmcPaymentsStore = mockk(relaxed = true),
        pendingAmcContractsStore = mockk(relaxed = true),
        requestServiceDraftStore = store,
    )

    private class EffectSink {
        val all = mutableListOf<RequestServiceViewModel.Effect>()
        val submitted = CompletableDeferred<RequestServiceViewModel.Effect.Submitted>()
    }

    private fun TestScope.collectEffects(model: RequestServiceViewModel): EffectSink {
        val sink = EffectSink()
        backgroundScope.launch {
            model.effects.collect {
                sink.all += it
                if (it is RequestServiceViewModel.Effect.Submitted) sink.submitted.complete(it)
            }
        }
        runCurrent()
        return sink
    }

    // ---------------------------------------------------------------- raw disk

    private suspend fun rawPrefs(): Preferences =
        awaitReal("a raw read of the preferences file", { "<unreadable>" }) { dataStore.data.first() }

    /** Suspends on the real DataStore flow until [predicate] holds, bounded by real time; reports the actual prefs on timeout. */
    private suspend fun awaitDisk(predicate: (Preferences) -> Boolean): Preferences =
        awaitReal("the preferences file to satisfy the predicate", { dataStore.data.first().asMap().toString() }) {
            dataStore.data.first { predicate(it) }
        }

    private fun parcelRoundTrip(bundle: Bundle): Bundle {
        val parcel = Parcel.obtain()
        return try {
            parcel.writeBundle(bundle)
            parcel.setDataPosition(0)
            checkNotNull(parcel.readBundle(javaClass.classLoader))
        } finally {
            parcel.recycle()
        }
    }

    // ---------------------------------------------------------------- (a)

    @Test fun `another account after real sign-out never sees or alters the previous draft on disk`() = integrationTest {
        val store = newStore()
        val handleA = SavedStateHandle()
        val vmA = bind(vm(store, handleA))
        val leaseA = checkNotNull(store.activeSession.value)
        assertSame(leaseA, vmA.state.value.formSession)

        vmA.onIssueChange(A_TEXT)
        vmA.onSiteAddressChange(A_ADDRESS)
        advanceTimeBy(10_001)
        runCurrent()
        // PRESENCE: A's bytes are on disk under A's owner/session keys.
        val prefsA = awaitDisk { it[OWNER] == "A" }
        assertEquals("session-A", prefsA[SESSION])
        assertTrue(checkNotNull(prefsA[JSON]).contains(A_TEXT))
        assertTrue(checkNotNull(prefsA[JSON]).contains(A_ADDRESS))

        // Real sign-out cleanup.
        signOutCleanup(store).wipeLocalUserState()
        advanceUntilIdle()
        val cleared = rawPrefs()
        assertNull(cleared[OWNER])
        assertNull(cleared[SESSION])
        assertNull(cleared[JSON])
        assertNull(store.activeSession.value)
        assertNull(vmA.state.value.formSession)
        assertEquals(RequestServiceViewModel.UiState(), vmA.state.value)
        assertTrue(handleA.keys().none { it.startsWith("req.") })
        signOut()
        runCurrent()
        assertNull(store.activeSession.value)

        // B signs in on the same device over a fresh handle.
        signIn("B", "session-B")
        runCurrent()
        val leaseB = checkNotNull(store.activeSession.value)
        assertEquals(RequestServiceDraftStore.Identity("B", "session-B"), leaseB.identity)
        val handleB = SavedStateHandle()
        val vmB = bind(vm(store, handleB))
        // The reused A ViewModel also re-binds to B's lease (production reuse path); let its disk read settle.
        awaitState(vmA, "the reused A form to finish its disk recovery check") { !it.checkingDraftRecovery }
        assertSame(leaseB, vmB.state.value.formSession)
        assertFalse(vmB.state.value.showDraftRecoveryBar)
        assertFalse(vmB.state.value.checkingDraftRecovery)
        assertEquals("", vmB.state.value.issue)
        assertNull(store.loadDraft(leaseB))

        vmB.onIssueChange(B_TEXT)
        advanceTimeBy(10_001)
        runCurrent()
        val prefsB = awaitDisk { it[OWNER] == "B" }
        assertEquals("session-B", prefsB[SESSION])
        val jsonB = checkNotNull(prefsB[JSON])
        assertTrue(jsonB.contains(B_TEXT))
        assertFalse(jsonB.contains(A_TEXT))
        assertFalse(jsonB.contains(A_ADDRESS))
        val bState = vmB.state.value

        // Replay everything A still holds: its lease against the store and its old ViewModel.
        store.saveDraft(leaseA, sampleRequestDraft("A late disk write"))
        store.clearDraft(leaseA)
        vmA.forFormSession(leaseA) { onIssueChange("A late typing") }
        advanceUntilIdle()
        val after = rawPrefs()
        assertEquals(prefsB.asMap(), after.asMap())
        assertTrue(checkNotNull(after[JSON]).contains(B_TEXT))
        assertFalse(checkNotNull(after[JSON]).contains("A late"))
        assertEquals(bState, vmB.state.value)
        assertEquals(B_TEXT, vmB.state.value.issue)
        assertEquals("", vmA.state.value.issue)
        assertFalse(handleA.contains("req.issue"))
        assertEquals(B_TEXT, store.loadDraft(leaseB)?.issue)
    }

    // ---------------------------------------------------------------- (b)

    @Test fun `late profile upload and submit callbacks that resolve after sign-out land nowhere`() = integrationTest {
        val store = newStore()
        val profileGate = CompletableDeferred<Result<Profile?>>()
        val uploadGate = CompletableDeferred<Result<StorageRepository.UploadReceipt>>()
        val createGate = CompletableDeferred<Result<RepairJob>>()
        var profileResumed = 0
        var uploadResumed = 0
        var createResumed = 0
        val gatedProfiles = mockk<ProfileRepository> {
            coEvery { fetchById("A") } coAnswers { profileGate.await().also { profileResumed++ } }
            coEvery { fetchById("B") } returns Result.success(null)
        }
        val gatedStorage = mockk<StorageRepository> {
            coEvery { upload(any(), any(), any(), any()) } coAnswers { uploadGate.await().also { uploadResumed++ } }
        }
        val gatedJobs = mockk<RepairJobRepository> {
            coEvery { create(any()) } coAnswers { createGate.await().also { createResumed++ } }
        }

        // A form 1: profile fetch and photo upload both left in flight.
        val handleA1 = SavedStateHandle()
        val vmA1 = bind(vm(store, handleA1, profileRepo = gatedProfiles, storage = gatedStorage))
        val leaseA = checkNotNull(store.activeSession.value)
        assertEquals("", vmA1.state.value.siteAddress)
        vmA1.onPhotoPicked("a-photo.jpg", byteArrayOf(1, 2, 3), "image/jpeg")
        runCurrent()
        assertTrue(vmA1.state.value.uploadingPhoto)
        coVerify(exactly = 1) { gatedProfiles.fetchById("A") }
        coVerify(exactly = 1) { gatedStorage.upload(any(), any(), any(), any()) }

        // A form 2: profile resolved (phone gate), submit left in flight. Its draft reaches disk first.
        val handleA2 = SavedStateHandle()
        val vmA2 = bind(vm(store, handleA2, jobRepo = gatedJobs))
        val a2Effects = collectEffects(vmA2)
        vmA2.onIssueChange(A_TEXT)
        vmA2.onSiteAddressChange(A_ADDRESS)
        advanceTimeBy(10_001)
        runCurrent()
        val prefsA = awaitDisk { it[OWNER] == "A" }
        assertEquals("session-A", prefsA[SESSION])
        assertTrue(checkNotNull(prefsA[JSON]).contains(A_TEXT))
        vmA2.onSubmit(3)
        runCurrent()
        assertTrue(vmA2.state.value.submitting)
        coVerify(exactly = 1) { gatedJobs.create(any()) }
        assertEquals(0, profileResumed)
        assertEquals(0, uploadResumed)
        assertEquals(0, createResumed)

        // Sign out for real, then B signs in and types its own draft.
        signOutCleanup(store).wipeLocalUserState()
        advanceUntilIdle()
        assertNull(rawPrefs()[OWNER])
        assertNull(store.activeSession.value)
        signOut()
        runCurrent()
        signIn("B", "session-B")
        runCurrent()
        val leaseB = checkNotNull(store.activeSession.value)
        val handleB = SavedStateHandle()
        val vmB = bind(vm(store, handleB, profileRepo = gatedProfiles))
        val bEffects = collectEffects(vmB)
        awaitState(vmA1, "the reused A form to finish its disk recovery check") { !it.checkingDraftRecovery }
        awaitState(vmA2, "the reused A form to finish its disk recovery check") { !it.checkingDraftRecovery }
        assertSame(leaseB, vmB.state.value.formSession)
        vmB.onIssueChange(B_TEXT)
        advanceTimeBy(10_001)
        runCurrent()
        val prefsB = awaitDisk { it[OWNER] == "B" }
        assertTrue(checkNotNull(prefsB[JSON]).contains(B_TEXT))
        val bState = vmB.state.value

        // Now A's three callbacks resolve.
        profileGate.complete(Result.success(profile(profileState = "Alpha state", profileDistrict = "Alpha district")))
        uploadGate.complete(Result.success(StorageRepository.UploadReceipt("repair-photos", A_LATE_PHOTO, "sha", 3)))
        createGate.complete(Result.success(repairJob("job-late", "RPR-LATE")))
        advanceUntilIdle()
        // The continuations provably resumed ...
        assertEquals(1, profileResumed)
        assertEquals(1, uploadResumed)
        assertEquals(1, createResumed)
        coVerify(exactly = 1) { gatedProfiles.fetchById("A") }
        coVerify(exactly = 1) { gatedStorage.upload(any(), any(), any(), any()) }
        coVerify(exactly = 1) { gatedJobs.create(any()) }

        // ... and the three sinks are unchanged. 1) B's ViewModel state.
        assertEquals(bState, vmB.state.value)
        assertEquals(B_TEXT, vmB.state.value.issue)
        assertTrue(vmB.state.value.photos.isEmpty())
        assertEquals("", vmB.state.value.siteAddress)
        assertNotEquals("Alpha district, Alpha state", vmB.state.value.siteAddress)
        // 2) Raw disk.
        val after = rawPrefs()
        assertEquals(prefsB.asMap(), after.asMap())
        val json = checkNotNull(after[JSON])
        assertTrue(json.contains(B_TEXT))
        assertFalse(json.contains(A_TEXT))
        assertFalse(json.contains(A_LATE_PHOTO))
        assertFalse(json.contains("Alpha"))
        // 3) B's handle.
        assertEquals("B", handleB.get<String>("req.ownerId"))
        assertEquals("session-B", handleB.get<String>("req.sessionId"))
        assertEquals(B_TEXT, handleB.get<String>("req.issue"))
        assertFalse(handleB.contains("req.photos"))
        assertFalse(handleB.contains("req.siteAddress"))
        // The old A forms (now blank, re-scoped to B) took nothing from A's callbacks either.
        assertTrue(vmA1.state.value.photos.isEmpty())
        assertFalse(vmA1.state.value.uploadingPhoto)
        assertEquals("", vmA1.state.value.siteAddress)
        assertFalse(handleA1.contains("req.photos"))
        assertFalse(handleA1.contains("req.siteAddress"))
        assertEquals("", vmA2.state.value.issue)
        assertFalse(vmA2.state.value.submitting)
        assertTrue(a2Effects.all.none { it is RequestServiceViewModel.Effect.Submitted })
        assertTrue(bEffects.all.none { it is RequestServiceViewModel.Effect.Submitted })
    }

    @Test fun `profile fetch seeds the site address when no sign-out intervenes`() = integrationTest {
        val store = newStore()
        val gate = CompletableDeferred<Result<Profile?>>()
        val profiles = mockk<ProfileRepository> { coEvery { fetchById("A") } coAnswers { gate.await() } }
        val handle = SavedStateHandle()
        val model = bind(vm(store, handle, profileRepo = profiles))
        assertNotNull(model.state.value.formSession)
        assertEquals("", model.state.value.siteAddress)
        gate.complete(Result.success(profile()))
        advanceUntilIdle()
        assertEquals("Hyderabad, Telangana", model.state.value.siteAddress)
        assertEquals("Hyderabad, Telangana", handle.get<String>("req.siteAddress"))
        coVerify(exactly = 1) { profiles.fetchById("A") }
    }

    @Test fun `photo upload appends the storage path when no sign-out intervenes`() = integrationTest {
        val store = newStore()
        val gate = CompletableDeferred<Result<StorageRepository.UploadReceipt>>()
        val pathSlot = slot<String>()
        val storage = mockk<StorageRepository> {
            coEvery { upload(any(), capture(pathSlot), any(), any()) } coAnswers { gate.await() }
        }
        val handle = SavedStateHandle()
        val model = bind(vm(store, handle, storage = storage))
        model.onPhotoPicked("a-photo.jpg", byteArrayOf(1, 2, 3), "image/jpeg")
        runCurrent()
        assertTrue(model.state.value.uploadingPhoto)
        val path = pathSlot.captured
        assertTrue(path, path.startsWith("A/issue-"))
        gate.complete(Result.success(StorageRepository.UploadReceipt("repair-photos", path, "sha", 3)))
        advanceUntilIdle()
        assertEquals(listOf(path), model.state.value.photos)
        assertFalse(model.state.value.uploadingPhoto)
        assertArrayEquals(arrayOf(path), handle.get<Array<String>>("req.photos"))
    }

    @Test fun `submit emits Submitted when no sign-out intervenes`() = integrationTest {
        val store = newStore()
        val gate = CompletableDeferred<Result<RepairJob>>()
        val jobs = mockk<RepairJobRepository> { coEvery { create(any()) } coAnswers { gate.await() } }
        val model = bind(vm(store, jobRepo = jobs))
        val lease = checkNotNull(store.activeSession.value)
        val effects = collectEffects(model)
        model.onIssueChange(A_TEXT)
        model.onSiteAddressChange(A_ADDRESS)
        advanceTimeBy(10_001)
        runCurrent()
        val prefs = awaitDisk { it[OWNER] == "A" }
        assertTrue(checkNotNull(prefs[JSON]).contains(A_TEXT))
        model.onSubmit(3)
        runCurrent()
        assertTrue(model.state.value.submitting)
        coVerify(exactly = 1) { jobs.create(any()) }
        gate.complete(Result.success(repairJob("job-42", "RPR-00042")))
        // The effect is emitted after the real clearDraft IO completes; wait for it, not for a timer.
        val submitted = awaitReal("the Submitted effect", { "effects so far: ${effects.all}; state: ${model.state.value}" }) {
            effects.submitted.await()
        }
        assertEquals("job-42", submitted.jobId)
        assertEquals("RPR-00042", submitted.jobNumber)
        assertSame(lease, submitted.formSession)
        assertEquals(1, effects.all.count { it is RequestServiceViewModel.Effect.Submitted })
        assertEquals("", model.state.value.issue)
        assertFalse(model.state.value.submitting)
        val cleared = awaitDisk { it[OWNER] == null }
        assertNull(cleared[JSON])
    }

    // ---------------------------------------------------------------- (c)

    @Test fun `same account signing in again with a new session id starts clean`() = integrationTest {
        val store = newStore()
        val vmA = bind(vm(store))
        assertNotNull(vmA.state.value.formSession)
        vmA.onIssueChange(A_TEXT)
        advanceTimeBy(10_001)
        runCurrent()
        val prefsA = awaitDisk { it[OWNER] == "A" }
        assertEquals("session-A", prefsA[SESSION])
        assertTrue(checkNotNull(prefsA[JSON]).contains(A_TEXT))

        signOutCleanup(store).wipeLocalUserState()
        advanceUntilIdle()
        signOut()
        runCurrent()
        signIn("A", "session-A2")
        runCurrent()
        val leaseA2 = checkNotNull(store.activeSession.value)
        assertEquals(RequestServiceDraftStore.Identity("A", "session-A2"), leaseA2.identity)

        val handle = SavedStateHandle()
        val model = bind(vm(store, handle))
        assertSame(leaseA2, model.state.value.formSession)
        val prefs = rawPrefs()
        assertNull(prefs[OWNER])
        assertNull(prefs[SESSION])
        assertNull(prefs[JSON])
        assertEquals("A", handle.get<String>("req.ownerId"))
        assertEquals("session-A2", handle.get<String>("req.sessionId"))
        assertFalse(handle.contains("req.issue"))
        assertNull(store.loadDraft(leaseA2))
        assertFalse(model.state.value.showDraftRecoveryBar)
        assertFalse(model.state.value.checkingDraftRecovery)
        assertEquals("", model.state.value.issue)
    }

    @Test fun `same session re-emission keeps the lease and the disk draft`() = integrationTest {
        val store = newStore()
        val handle = SavedStateHandle()
        val model = bind(vm(store, handle))
        val leaseA = checkNotNull(store.activeSession.value)
        model.onIssueChange(A_TEXT)
        advanceTimeBy(10_001)
        runCurrent()
        val before = awaitDisk { it[OWNER] == "A" }
        assertEquals("session-A", before[SESSION])
        assertTrue(checkNotNull(before[JSON]).contains(A_TEXT))

        // SDK re-initialisation / token refresh: Unknown, then the same login again (identity unchanged).
        auth.setSession(AuthSession.Unknown)
        runCurrent()
        assertSame(leaseA, store.activeSession.value)
        auth.setSession(AuthSession.SignedIn("A", "a@test.invalid"))
        runCurrent()
        assertSame(leaseA, store.activeSession.value)
        assertSame(leaseA, model.state.value.formSession)
        assertEquals(A_TEXT, model.state.value.issue)
        assertEquals(A_TEXT, handle.get<String>("req.issue"))
        assertEquals(before.asMap(), rawPrefs().asMap())
        assertEquals(A_TEXT, store.loadDraft(leaseA)?.issue)
    }

    // ---------------------------------------------------------------- (d)

    @Test fun `req keys survive a Parcel round trip for the same session and never render for a foreign owner`() = integrationTest {
        val store = newStore()
        val storage = mockk<StorageRepository> {
            coEvery { upload(any(), any(), any(), any()) } coAnswers {
                Result.success(StorageRepository.UploadReceipt("repair-photos", secondArg<String>(), "sha", 3))
            }
        }
        val handle = SavedStateHandle()
        val original = bind(vm(store, handle, storage = storage))
        val leaseA = checkNotNull(store.activeSession.value)
        original.onIssueChange(A_TEXT)
        original.onSiteAddressChange(A_ADDRESS)
        original.onPickedDateChange(PICKED_DATE)
        original.onSiteCoordsChange(17.385, 78.4867)
        original.onSelectedSlotChange(2)
        original.onPhotoPicked("a-photo.jpg", byteArrayOf(1, 2, 3), "image/jpeg")
        runCurrent()
        val originalState = original.state.value
        assertEquals(1, originalState.photos.size)
        assertTrue(originalState.photos.single().startsWith("A/issue-"))

        // Process death: Bundle -> Parcel bytes -> new Bundle -> new handle.
        val saved: Bundle = handle.savedStateProvider().saveState()
        val restoredBundle = parcelRoundTrip(saved)
        assertNotSame(saved, restoredBundle)
        val restoredHandle = SavedStateHandle.createHandle(restoredBundle, null)
        assertEquals("A", restoredHandle.get<String>("req.ownerId"))
        assertEquals("session-A", restoredHandle.get<String>("req.sessionId"))
        assertEquals(A_TEXT, restoredHandle.get<String>("req.issue"))
        assertArrayEquals(originalState.photos.toTypedArray(), restoredHandle.get<Array<String>>("req.photos"))
        assertEquals(PICKED_DATE, restoredHandle.get<Long>("req.pickedDate"))
        assertEquals(17.385, checkNotNull(restoredHandle.get<Double>("req.siteLat")), 0.0)
        assertEquals(78.4867, checkNotNull(restoredHandle.get<Double>("req.siteLng")), 0.0)
        assertEquals(2, restoredHandle.get<Int>("req.selectedSlot"))

        val recreated = bind(vm(store, restoredHandle, storage = storage))
        assertSame(leaseA, recreated.state.value.formSession)
        assertEquals(A_TEXT, recreated.state.value.issue)
        assertEquals(A_ADDRESS, recreated.state.value.siteAddress)
        assertEquals(originalState.photos, recreated.state.value.photos)
        assertEquals(PICKED_DATE, recreated.state.value.pickedDateMillis)
        assertEquals(17.385, checkNotNull(recreated.state.value.siteLatitude), 0.0)
        assertEquals(78.4867, checkNotNull(recreated.state.value.siteLongitude), 0.0)
        assertEquals(2, recreated.state.value.selectedSlot)
        assertFalse(recreated.state.value.showDraftRecoveryBar)
        assertFalse(recreated.state.value.checkingDraftRecovery)

        // Foreign owner in the parcel (same session id) against A's live lease.
        val foreign = SavedStateHandle(
            mapOf(
                "req.ownerId" to "B", "req.sessionId" to "session-A",
                "req.issue" to FOREIGN_TEXT, "req.siteAddress" to FOREIGN_ADDRESS,
                "req.photos" to arrayOf("B/private.jpg"), "req.pickedDate" to PICKED_DATE,
                "req.siteLat" to 17.0, "req.siteLng" to 78.0, "req.selectedSlot" to 2,
            ),
        )
        val foreignRestored = SavedStateHandle.createHandle(parcelRoundTrip(foreign.savedStateProvider().saveState()), null)
        // PRESENCE: the parcel really carried the foreign fields.
        assertEquals("B", foreignRestored.get<String>("req.ownerId"))
        assertEquals(FOREIGN_TEXT, foreignRestored.get<String>("req.issue"))
        assertArrayEquals(arrayOf("B/private.jpg"), foreignRestored.get<Array<String>>("req.photos"))
        val foreignVm = vm(store, foreignRestored, storage = storage)
        assertEquals("", foreignVm.state.value.issue)
        bind(foreignVm)
        assertSame(leaseA, foreignVm.state.value.formSession)
        assertEquals("", foreignVm.state.value.issue)
        assertTrue(foreignVm.state.value.photos.isEmpty())
        assertNull(foreignVm.state.value.pickedDateMillis)
        assertNull(foreignVm.state.value.siteLatitude)
        assertNull(foreignVm.state.value.siteLongitude)
        assertEquals(-1, foreignVm.state.value.selectedSlot)
        assertNotEquals(FOREIGN_ADDRESS, foreignVm.state.value.siteAddress)
        assertFalse(foreignRestored.contains("req.issue"))
        assertFalse(foreignRestored.contains("req.photos"))
        assertFalse(foreignRestored.contains("req.pickedDate"))
        assertEquals("A", foreignRestored.get<String>("req.ownerId"))
        assertEquals("session-A", foreignRestored.get<String>("req.sessionId"))
    }

    private companion object {
        val JSON = stringPreferencesKey("draft_json")
        val OWNER = stringPreferencesKey("draft_owner_id")
        val SESSION = stringPreferencesKey("draft_session_id")

        /** Real-time bound for waits on real disk IO; generous for a 2-core CI runner, tiny against runTest's 60 s. */
        const val REAL_WAIT_MS = 10_000L
        const val A_TEXT = "A private issue text"
        const val A_ADDRESS = "A ward 3, Alpha Hospital, Hyderabad"
        const val A_LATE_PHOTO = "A/issue-late.jpg"
        const val B_TEXT = "B private issue text"
        const val FOREIGN_TEXT = "Foreign private issue text"
        const val FOREIGN_ADDRESS = "Foreign private site"
        const val PICKED_DATE = 1_800_000_000_000L
    }
}
