package com.equipseva.app.core.data.repair

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.preferencesOf
import androidx.datastore.preferences.core.stringPreferencesKey
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.testing.FakeAuthRepository
import java.io.IOException
import java.util.Base64
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.*
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RequestServiceDraftStoreTest {
    private fun TestScope.ownershipFor(fixture: DraftStoreFixture) = LocalSessionOwnership(
        fixture.auth,
        {
            fixture.identity?.let { identity ->
                identity.sessionId?.let { LocalSessionOwnership.Identity(identity.ownerId, it) }
            }
        },
        backgroundScope,
    )

    @Test fun `ticketed draft fence is synchronous and delayed clear cannot remove B draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        val ownership = ownershipFor(fixture)
        runCurrent()
        val aLease = fixture.lease()
        fixture.store.saveDraft(aLease, sampleRequestDraft("A draft"))
        val ticketA = requireNotNull(ownership.capture())
        val clearHandle = requireNotNull(fixture.store.fenceForSignOut(ticketA, ownership))
        assertNull("A lease must retire before disk suspension", fixture.store.activeSession.value)

        val gate = CompletableDeferred<Unit>()
        fixture.disk.nextAdmissionGate = gate
        val clear = async { fixture.store.clearFencedForSignOut(clearHandle) }
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        val bLease = fixture.lease()
        val bDraft = sampleRequestDraft("B draft")
        fixture.store.saveDraft(bLease, bDraft)
        assertEquals("B must commit while A is still held before edit admission", bDraft,
            fixture.store.loadDraft(bLease))
        gate.complete(Unit)
        clear.await()
        assertEquals(bDraft, fixture.store.loadDraft(bLease))
        assertFalse(fixture.store.isCurrent(aLease))
    }

    @Test fun `stale or missing cleanup ticket cannot retire B draft lease`() = runTest {
        val fixture = DraftStoreFixture(this)
        val ownership = ownershipFor(fixture)
        runCurrent()
        val ticketA = requireNotNull(ownership.capture())
        fixture.signIn("B", "session-B")
        runCurrent()
        val bLease = fixture.lease()
        val bDraft = sampleRequestDraft("B stays")
        fixture.store.saveDraft(bLease, bDraft)
        assertNull(fixture.store.fenceForSignOut(null, ownership))
        assertNull(fixture.store.fenceForSignOut(ticketA, ownership))
        assertTrue("a stale sign-out must leave B's lease active", fixture.store.isCurrent(bLease))
        assertEquals(bDraft, fixture.store.loadDraft(bLease))
    }

    @Test fun `A B A observation rejects old A fence even when the session claim matches`() = runTest {
        val fixture = DraftStoreFixture(this)
        val ownership = ownershipFor(fixture)
        runCurrent()
        val oldTicket = requireNotNull(ownership.capture())
        fixture.signIn("B", "session-B")
        runCurrent()
        fixture.signIn("A", "session-A")
        runCurrent()
        val freshLease = fixture.lease()
        val freshDraft = sampleRequestDraft("new A draft")
        fixture.store.saveDraft(freshLease, freshDraft)
        assertNull(fixture.store.fenceForSignOut(oldTicket, ownership))
        assertTrue(fixture.store.isCurrent(freshLease))
        assertEquals(freshDraft, fixture.store.loadDraft(freshLease))
    }

    @Test fun `old A clear held on disk cannot erase fresh A after observed A B A`() = runTest {
        val fixture = DraftStoreFixture(this)
        val ownership = ownershipFor(fixture)
        runCurrent()
        val oldLease = fixture.lease()
        fixture.store.saveDraft(oldLease, sampleRequestDraft("old A draft"))
        val oldTicket = requireNotNull(ownership.capture())
        val oldClearHandle = requireNotNull(fixture.store.fenceForSignOut(oldTicket, ownership))
        val gate = CompletableDeferred<Unit>()
        fixture.disk.nextAdmissionGate = gate
        val oldClear = async { fixture.store.clearFencedForSignOut(oldClearHandle) }
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        fixture.signIn("A", "session-A")
        runCurrent()
        val freshLease = fixture.lease()
        val freshDraft = sampleRequestDraft("new A draft")
        fixture.store.saveDraft(freshLease, freshDraft)
        assertEquals("fresh A must commit before old A enters the transform", freshDraft,
            fixture.store.loadDraft(freshLease))
        gate.complete(Unit)
        oldClear.await()
        assertEquals(freshDraft, fixture.store.loadDraft(freshLease))
        assertFalse(fixture.store.isCurrent(oldLease))
    }

    @Test fun `cancelled A disk clear does not erase B draft after its gate releases`() = runTest {
        val fixture = DraftStoreFixture(this)
        val ownership = ownershipFor(fixture)
        runCurrent()
        val ticketA = requireNotNull(ownership.capture())
        val oldHandle = requireNotNull(fixture.store.fenceForSignOut(ticketA, ownership))
        val gate = CompletableDeferred<Unit>()
        fixture.disk.nextWriteGate = gate
        var cancelled = false
        val clear = launch {
            try {
                fixture.store.clearFencedForSignOut(oldHandle)
            } catch (_: CancellationException) {
                cancelled = true
            }
        }
        runCurrent()
        clear.cancel(CancellationException("A cleanup cancelled"))
        gate.complete(Unit)
        clear.join()
        assertTrue("DataStore cancellation must escape A clear", cancelled)

        fixture.signIn("B", "session-B")
        runCurrent()
        val bLease = fixture.lease()
        val bDraft = sampleRequestDraft("B after cancellation")
        fixture.store.saveDraft(bLease, bDraft)
        assertEquals(bDraft, fixture.store.loadDraft(bLease))
    }

    @Test fun `owner and login session isolate persistence and stale operations`() = runTest {
        val fixture = DraftStoreFixture(this)
        val old = fixture.lease()
        fixture.store.saveDraft(old, sampleRequestDraft("A's issue"))
        fixture.signIn("B", "session-B")
        runCurrent()
        val current = fixture.lease()
        assertNull(fixture.store.loadDraft(current))
        val bDraft = sampleRequestDraft("B's issue")
        fixture.store.saveDraft(current, bDraft)
        fixture.store.saveDraft(old, sampleRequestDraft("late A autosave"))
        fixture.store.clearDraft(old)
        assertNull(fixture.store.loadDraft(old))
        assertEquals(bDraft, fixture.store.loadDraft(current))
    }

    @Test fun `write queued before logout cannot recreate draft after fresh login of same owner`() = runTest {
        val fixture = DraftStoreFixture(this)
        val old = fixture.lease()
        val release = CompletableDeferred<Unit>()
        fixture.disk.nextWriteGate = release
        val lateSave = async { fixture.store.saveDraft(old, sampleRequestDraft("late A")) }
        runCurrent()
        val cleanup = async { fixture.store.fenceAndClearForSignOut() }
        runCurrent()
        assertFalse(fixture.store.isCurrent(old))
        fixture.signIn("A", "new-session-A")
        runCurrent()
        release.complete(Unit)
        lateSave.await()
        cleanup.await()
        val current = fixture.lease()
        assertNotEquals(old, current)
        assertNull(fixture.store.loadDraft(current))
        val newDraft = sampleRequestDraft("fresh A")
        fixture.store.saveDraft(current, newDraft)
        fixture.store.clearDraft(old)
        assertEquals(newDraft, fixture.store.loadDraft(current))
    }

    @Test fun `signout fences before disk failure and cached SDK identity cannot reacquire`() = runTest {
        val fixture = DraftStoreFixture(this)
        val lease = fixture.lease()
        fixture.store.saveDraft(lease, sampleRequestDraft())
        fixture.disk.nextWriteFailure = IOException("disk unavailable")
        assertTrue(runCatching { fixture.store.fenceAndClearForSignOut() }.isFailure)
        fixture.auth.setSession(AuthSession.SignedIn("A", "changed-email@test.invalid"))
        runCurrent()
        assertNull(fixture.store.activeSession.value)
        fixture.store.saveDraft(lease, sampleRequestDraft("late callback"))
        assertNull(fixture.store.loadDraft(lease))
    }

    @Test fun `SDK identity check rejects stale work even before auth observer is dispatched`() = runTest {
        val fixture = DraftStoreFixture(this)
        val lease = fixture.lease()
        fixture.identity = RequestServiceDraftStore.Identity("B", "session-B")
        assertFalse(fixture.store.isCurrent(lease))
        fixture.store.saveDraft(lease, sampleRequestDraft())
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `explicit logout rejects reused cached login even across SignedOut emission`() = runTest {
        val fixture = DraftStoreFixture(this)
        val old = fixture.lease()
        fixture.store.fenceAndClearForSignOut()
        fixture.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        fixture.auth.setSession(AuthSession.SignedIn("A", "a@test.invalid"))
        runCurrent()
        assertNull(fixture.store.activeSession.value)
        assertFalse(fixture.store.isCurrent(old))
        fixture.signIn("A", "fresh-login")
        runCurrent()
        assertTrue(fixture.store.isCurrent(fixture.lease()))
    }

    @Test fun `clearing invalidates previously captured autosave but permits genuinely new edits`() = runTest {
        val fixture = DraftStoreFixture(this)
        val lease = fixture.lease()
        val oldEpoch = fixture.store.writeEpoch(lease)
        fixture.store.saveDraft(lease, sampleRequestDraft("completed draft"), oldEpoch)
        fixture.store.clearDraft(lease)
        fixture.store.saveDraft(lease, sampleRequestDraft("late snapshot"), oldEpoch)
        assertNull(fixture.store.loadDraft(lease))
        fixture.store.saveDraft(lease, sampleRequestDraft("new request"))
        assertEquals("new request", fixture.store.loadDraft(lease)?.issue)
    }

    @Test fun `same login survives refresh and store recreation`() = runTest {
        val fixture = DraftStoreFixture(this)
        val lease = fixture.lease()
        val draft = sampleRequestDraft()
        fixture.store.saveDraft(lease, draft)
        fixture.auth.setSession(AuthSession.Unknown)
        runCurrent()
        fixture.auth.setSession(AuthSession.SignedIn("A", "a@test.invalid"))
        runCurrent()
        assertEquals(lease, fixture.lease())
        val reopened = RequestServiceDraftStore(
            fixture.disk, fixture.auth, { fixture.identity }, backgroundScope, { fixture.now },
        )
        assertEquals(draft, reopened.loadDraft(checkNotNull(reopened.activeSession.value)))
    }

    @Test fun `legacy ownerless and malformed drafts are discarded`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.disk.replace(preferencesOf(
            stringPreferencesKey("draft_json") to "{\"issue\":\"private legacy data\"}",
            longPreferencesKey("draft_timestamp_ms") to fixture.now,
        ))
        assertNull(fixture.store.loadDraft(fixture.lease()))
        assertTrue(fixture.disk.value.asMap().isEmpty())
        fixture.disk.replace(preferencesOf(
            stringPreferencesKey("draft_json") to "not-json",
            longPreferencesKey("draft_timestamp_ms") to fixture.now,
            stringPreferencesKey("draft_owner_id") to "A",
            stringPreferencesKey("draft_session_id") to "session-A",
        ))
        assertNull(fixture.store.loadDraft(fixture.lease()))
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `expiry boundary remains thirty days`() = runTest {
        val fixture = DraftStoreFixture(this)
        val draft = sampleRequestDraft()
        fixture.store.saveDraft(fixture.lease(), draft)
        fixture.now += 30L * 24 * 60 * 60 * 1000
        assertEquals(draft, fixture.store.loadDraft(fixture.lease()))
        fixture.now++
        assertNull(fixture.store.loadDraft(fixture.lease()))
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `stale invalid-draft cleanup cannot delete a newer draft`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.disk.replace(preferencesOf(
            stringPreferencesKey("draft_json") to "old malformed JSON",
            longPreferencesKey("draft_timestamp_ms") to fixture.now,
        ))
        val release = CompletableDeferred<Unit>()
        fixture.disk.nextWriteGate = release
        val oldRead = async { fixture.store.loadDraft(fixture.lease()) }
        runCurrent()
        fixture.signIn("B", "session-B")
        runCurrent()
        val bLease = fixture.lease()
        val bSave = async { fixture.store.saveDraft(bLease, sampleRequestDraft("B's fresh draft")) }
        runCurrent()
        release.complete(Unit)
        oldRead.await()
        bSave.await()
        assertEquals("B's fresh draft", fixture.store.loadDraft(bLease)?.issue)
    }

    @Test fun `missing session claim disables persistence without disabling form lease`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.signIn("A", null)
        runCurrent()
        val lease = fixture.lease()
        assertTrue(fixture.store.isCurrent(lease))
        fixture.store.saveDraft(lease, sampleRequestDraft())
        assertNull(fixture.store.loadDraft(lease))
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `memory only same owner login recovers only after SDK session was actually cleared`() = runTest {
        val fixture = DraftStoreFixture(this)
        fixture.signIn("A", null)
        runCurrent()
        val old = fixture.lease()
        fixture.store.fenceAndClearForSignOut()
        // Auth says SignedOut but cached SDK identity still exists: do not unblock.
        fixture.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        fixture.signIn("A", null)
        runCurrent()
        assertNull(fixture.store.activeSession.value)
        // Local SDK signout clears its session, followed by a genuine fresh login.
        fixture.identity = null
        fixture.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        fixture.signIn("A", null)
        runCurrent()
        assertNotEquals(old, fixture.lease())
        assertTrue(fixture.store.isCurrent(fixture.lease()))
        assertFalse(fixture.store.isCurrent(old))
        fixture.store.saveDraft(fixture.lease(), sampleRequestDraft())
        assertTrue(fixture.disk.value.asMap().isEmpty())
    }

    @Test fun `session scope parser rejects malformed absent and mismatched claims`() {
        fun token(payload: String) = "header." + Base64.getUrlEncoder().withoutPadding()
            .encodeToString(payload.toByteArray()) + ".signature"
        assertEquals(RequestServiceDraftStore.Identity("A", "session-A"),
            RequestServiceDraftStore.identityFromAccessToken("A", token("""{"sub":"A","session_id":"session-A"}""")))
        assertNull(RequestServiceDraftStore.identityFromAccessToken("B", token("""{"sub":"A","session_id":"s"}""")))
        assertNull(RequestServiceDraftStore.identityFromAccessToken("A", token("""{"sub":"A"}""")))
        assertNull(RequestServiceDraftStore.identityFromAccessToken("A", "invalid"))
    }
}

/** Real DataStore transformations with serialized writes and controllable IO stalls. */
internal class DraftPreferencesStore : DataStore<Preferences> {
    private val state = MutableStateFlow<Preferences>(emptyPreferences())
    private val mutex = Mutex()
    /** Stall one caller before DataStore admits the write, without blocking newer writers. */
    var nextAdmissionGate: CompletableDeferred<Unit>? = null
    var nextWriteGate: CompletableDeferred<Unit>? = null
    var readGate: CompletableDeferred<Unit>? = null
    var nextWriteFailure: Exception? = null
    var nextReadFailure: Exception? = null
    val value: Preferences get() = state.value
    override val data: Flow<Preferences> = flow {
        readGate?.await()
        nextReadFailure?.let { nextReadFailure = null; throw it }
        emitAll(state)
    }
    override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences {
        val admission = nextAdmissionGate
        nextAdmissionGate = null
        admission?.await()
        return mutex.withLock {
            val gate = nextWriteGate
            nextWriteGate = null
            gate?.await()
            nextWriteFailure?.let { nextWriteFailure = null; throw it }
            transform(state.value).also { state.value = it }
        }
    }
    fun replace(value: Preferences) { state.value = value }
}

internal class DraftStoreFixture(scope: kotlinx.coroutines.test.TestScope) {
    val disk = DraftPreferencesStore()
    val auth = FakeAuthRepository(AuthSession.SignedIn("A", "a@test.invalid"))
    var identity: RequestServiceDraftStore.Identity? = RequestServiceDraftStore.Identity("A", "session-A")
    var now = 1_000_000L
    val store = RequestServiceDraftStore(disk, auth, { identity }, scope.backgroundScope, { now })
    fun lease() = checkNotNull(store.activeSession.value)
    fun signIn(owner: String, session: String?) {
        identity = RequestServiceDraftStore.Identity(owner, session)
        // Emit a changed email so tests can deliver a same-owner new-login event.
        auth.setSession(AuthSession.SignedIn(owner, "$session@test.invalid"))
    }
}

internal fun sampleRequestDraft(issue: String = "Equipment display is broken") = RequestServiceFormDraft(
    category = RepairEquipmentCategory.PatientMonitoring.storageKey,
    urgency = RepairJobUrgency.Scheduled.storageKey,
    brand = "Sample brand", model = "Model 1", serial = "SN-123",
    siteAddress = "Sample hospital address", siteLocation = "Service room",
    pickedDateMillis = null, siteLatitude = 17.0, siteLongitude = 78.0,
    issue = issue, budget = "1000", photoUris = listOf("A/issue-example.jpg"),
)
