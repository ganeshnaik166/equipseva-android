package com.equipseva.app.navigation

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.RecordingUserPrefs
import io.mockk.coEvery
import io.mockk.mockk
import java.io.IOException
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeepLinkHostEngineerStatusTest {

    private val fixtures = mutableListOf<Fixture>()

    @Before
    fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @After
    fun tearDown() {
        fixtures.forEach { it.close() }
        Dispatchers.resetMain()
    }

    private class EngineerFetch(val userId: String) {
        lateinit var job: Job
        val result = CompletableDeferred<Result<Engineer?>>()
        fun complete(engineer: Engineer?) {
            result.complete(Result.success(engineer))
        }

        fun completeFailure(cause: Throwable) {
            result.complete(Result.failure(cause))
        }
    }

    private class Fixture(
        initialSession: AuthSession,
        val router: DeepLinkRouter = mockk(relaxed = true),
        sessionFlow: Flow<AuthSession>? = null,
        cooperative: Boolean = false,
    ) {
        val auth = FakeAuthRepository(initialSession)
        val requests = mutableListOf<EngineerFetch>()
        val engineerRepository = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } coAnswers {
                val request = EngineerFetch(firstArg())
                request.job = currentCoroutineContext()[Job]!!
                requests += request
                if (cooperative) request.result.await()
                else withContext(NonCancellable) { request.result.await() }
            }
        }
        val prefs = RecordingUserPrefs.create()
        val host = DeepLinkHost(
            router = router,
            userPrefs = prefs.mock,
            authRepository = if (sessionFlow == null) auth else object : AuthRepository by auth {
                override val sessionState: Flow<AuthSession> = checkNotNull(sessionFlow)
            },
            engineerRepository = engineerRepository,
        )

        fun session(session: AuthSession) {
            auth.setSession(session)
        }

        fun close() {
            host.viewModelScope.cancel()
            requests.forEach { it.result.completeExceptionally(CancellationException("Test ended")) }
        }
    }

    private fun fixture(
        initialSession: AuthSession = AuthSession.SignedOut,
        router: DeepLinkRouter = mockk(relaxed = true),
        sessionFlow: Flow<AuthSession>? = null,
        cooperative: Boolean = false,
    ) = Fixture(initialSession, router, sessionFlow, cooperative).also { fixtures += it }

    private fun signedIn(userId: String, email: String? = "$userId@test.invalid") =
        AuthSession.SignedIn(userId, email)

    private fun engineer(
        userId: String,
        status: VerificationStatus,
    ): Engineer = Engineer(
        id = "engineer-row-$userId",
        userId = userId,
        aadhaarNumber = null,
        aadhaarVerified = false,
        qualifications = emptyList(),
        specializations = emptyList(),
        brandsServiced = emptyList(),
        experienceYears = 0,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = status,
        backgroundCheckStatus = VerificationStatus.Pending,
        certificates = emptyList(),
    )

    @Test
    fun `signed out resets engineer status`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()

        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)

        f.session(AuthSession.SignedOut)
        runCurrent()
        assertNull(f.host.engineerStatus.value)
    }

    @Test
    fun `same account sign-out then sign-in refetches status`() = runTest {
        val f = fixture(signedIn("A", "a@test.invalid"))
        runCurrent()
        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)

        f.session(AuthSession.SignedOut)
        runCurrent()
        assertNull(f.host.engineerStatus.value)

        f.session(signedIn("A", "a2@test.invalid"))
        runCurrent()
        assertEquals(2, f.requests.size)
        f.requests.last().complete(engineer("A", VerificationStatus.Rejected))
        runCurrent()
        assertEquals(VerificationStatus.Rejected, f.host.engineerStatus.value)
    }

    @Test
    fun `A to B replacement ignores stale first request`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()

        val aInitial = f.requests.single()
        f.session(signedIn("B"))
        runCurrent()
        val bRequest = f.requests.last()

        aInitial.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        bRequest.complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `A to B to A publishes only final A request`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()

        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)

        f.session(signedIn("B"))
        runCurrent()
        val bRequest = f.requests.last()

        f.session(signedIn("A"))
        runCurrent()
        val aFinal = f.requests.last()

        bRequest.complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        aFinal.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
        assertEquals(3, f.requests.size)
    }

    @Test
    fun `late noncooperative response cannot republish into a newer login`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()

        f.session(signedIn("B"))
        runCurrent()

        val staleA = f.requests.first()
        val bRequest = f.requests.last()
        bRequest.complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
        staleA.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `duplicate signed in and email-only events do not refetch same login`() = runTest {
        val f = fixture(signedIn("A", "a@test.invalid"))
        runCurrent()
        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()

        f.session(signedIn("A", "new-a@test.invalid"))
        runCurrent()
        assertEquals(1, f.requests.size)
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `blank user id never triggers fetch and keeps status null`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.session(signedIn("", "noid@test.invalid"))
        runCurrent()

        assertEquals(1, f.requests.size)
        assertNull(f.host.engineerStatus.value)
    }

    @Test
    fun `Unknown clears status and refreshes again on next explicit sign-in`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()

        f.session(AuthSession.Unknown)
        runCurrent()
        assertNull(f.host.engineerStatus.value)

        f.session(signedIn("A"))
        runCurrent()
        assertEquals(2, f.requests.size)
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `manual refresh does not queue while signed out then runs fresh on sign in`() = runTest {
        val f = fixture(AuthSession.SignedOut)
        runCurrent()

        f.host.refreshEngineerStatus()
        runCurrent()

        f.session(signedIn("A"))
        runCurrent()

        assertEquals(1, f.requests.size)
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `failed manual refresh clears previous status and allows a fresh retry`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        val initial = f.requests.single()
        initial.complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)

        f.host.refreshEngineerStatus()
        runCurrent()
        f.requests.last().completeFailure(IOException("offline"))
        runCurrent()

        assertNull(f.host.engineerStatus.value)
        assertEquals(2, f.requests.size)
        f.host.refreshEngineerStatus()
        runCurrent()
        f.requests.last().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `fetch failure keeps engineer status null`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.requests.single().completeFailure(IOException("network"))
        runCurrent()

        assertNull(f.host.engineerStatus.value)
        assertEquals(1, f.requests.size)
    }

    @Test
    fun `refresh before first session emission is dropped instead of waiting for login`() = runTest {
        val ready = CompletableDeferred<Unit>()
        val sessions = MutableStateFlow<AuthSession>(signedIn("A"))
        var activeSubscriptions = 0
        // Initially unavailable; once ready, this supplies a current replayable
        // value like the SDK source. The early manual call must not wait for it.
        val f = fixture(sessionFlow = flow {
            activeSubscriptions++
            try {
                ready.await()
                sessions.collect { emit(it) }
            } finally {
                activeSubscriptions--
            }
        })
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, activeSubscriptions)
        assertEquals(0, f.requests.size)
        ready.complete(Unit)
        runCurrent()
        assertEquals(1, f.requests.size)
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `manual refresh leaves only the long lived auth observer subscribed`() = runTest {
        val sessions = MutableSharedFlow<AuthSession>(replay = 1)
        sessions.emit(signedIn("A"))
        var activeSubscriptions = 0
        // A synchronous current-auth probe is permitted. The contract is no
        // retained subscriber or deferred work for an account that signs in
        // later, not an implementation-specific lifetime subscription count.
        val f = fixture(sessionFlow = flow {
            activeSubscriptions++
            try {
                sessions.collect { emit(it) }
            } finally {
                activeSubscriptions--
            }
        })
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, activeSubscriptions)
        assertEquals(2, f.requests.size)
    }

    private fun TestScope.recordStatuses(f: Fixture): MutableList<VerificationStatus?> {
        val values = mutableListOf<VerificationStatus?>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            f.host.engineerStatus.collect { values += it }
        }
        return values
    }

    private fun TestScope.assertQueuedPublicationRejected(next: AuthSession) {
        val f = fixture(signedIn("A"))
        val statuses = recordStatuses(f)
        runCurrent()
        val old = f.requests.single()

        // Release the response FIRST, so its continuation is ahead of the
        // auth observer. Raw auth changes before either continuation runs.
        old.complete(engineer("A", VerificationStatus.Verified))
        f.session(next)
        runCurrent()
        assertFalse("Stale A must never appear in the full emission trace: $statuses",
            VerificationStatus.Verified in statuses)
        assertNull(f.host.engineerStatus.value)

        val current = (next as? AuthSession.SignedIn)?.userId ?: "A"
        if (next !is AuthSession.SignedIn) {
            f.session(signedIn(current))
            runCurrent()
        }
        assertEquals(listOf("A", current), f.requests.map { it.userId })
        f.requests.last().complete(engineer(current, VerificationStatus.Pending))
        runCurrent()
        assertEquals(listOf(null, VerificationStatus.Pending), statuses)
    }

    @Test
    fun `queued A response cannot publish after raw auth became B before observer`() = runTest {
        assertQueuedPublicationRejected(signedIn("B"))
    }

    @Test
    fun `queued A response cannot publish after raw auth became Unknown before observer`() = runTest {
        assertQueuedPublicationRejected(AuthSession.Unknown)
    }

    @Test
    fun `queued A response cannot publish after raw auth became signed out before observer`() = runTest {
        assertQueuedPublicationRejected(AuthSession.SignedOut)
    }

    private fun TestScope.assertQueuedAdmissionRejected(next: AuthSession) {
        val f = fixture(signedIn("A"))
        val statuses = recordStatuses(f)
        runCurrent()
        val old = f.requests.single()

        // The refresh launch is queued before the auth observer; it must still
        // recheck raw auth before calling fetchByUserId under replacement auth.
        f.host.refreshEngineerStatus()
        f.session(next)
        runCurrent()
        val expected = if (next is AuthSession.SignedIn) listOf("A", next.userId) else listOf("A")
        assertEquals("No extra A fetch may enter after raw auth changes", expected, f.requests.map { it.userId })

        old.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertFalse(VerificationStatus.Verified in statuses)
        if (next !is AuthSession.SignedIn) {
            f.session(signedIn("B"))
            runCurrent()
        }
        assertEquals(listOf("A", "B"), f.requests.map { it.userId })
        f.requests.last().complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(listOf(null, VerificationStatus.Pending), statuses)
    }

    @Test
    fun `queued manual fetch does not enter after raw auth became B before observer`() = runTest {
        assertQueuedAdmissionRejected(signedIn("B"))
    }

    @Test
    fun `queued manual fetch does not enter after raw auth became Unknown before observer`() = runTest {
        assertQueuedAdmissionRejected(AuthSession.Unknown)
    }

    @Test
    fun `queued manual fetch does not enter after raw auth became signed out before observer`() = runTest {
        assertQueuedAdmissionRejected(AuthSession.SignedOut)
    }

    @Test
    fun `foreign engineer row is rejected and a valid same login retry can publish`() = runTest {
        val f = fixture(signedIn("A"))
        val statuses = recordStatuses(f)
        runCurrent()
        f.requests.single().complete(engineer("B", VerificationStatus.Verified))
        runCurrent()
        assertEquals(listOf<VerificationStatus?>(null), statuses)

        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(listOf("A", "A"), f.requests.map { it.userId })
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(listOf(null, VerificationStatus.Pending), statuses)
    }

    @Test
    fun `blank engineer row owners are rejected without poisoning a valid retry`() = runTest {
        for (rowOwner in listOf("", " ", "\t\n")) {
            val f = fixture(signedIn("A"))
            val statuses = recordStatuses(f)
            runCurrent()
            f.requests.single().complete(engineer(rowOwner, VerificationStatus.Verified))
            runCurrent()
            assertEquals("Blank row owner must never publish: '$rowOwner'",
                listOf<VerificationStatus?>(null), statuses)

            f.host.refreshEngineerStatus()
            runCurrent()
            assertEquals(listOf("A", "A"), f.requests.map { it.userId })
            f.requests.last().complete(engineer("A", VerificationStatus.Pending))
            runCurrent()
            assertEquals(listOf(null, VerificationStatus.Pending), statuses)
        }
    }

    @Test
    fun `mapped StateFlow supplies live auth when its full observer is behind`() = runTest {
        val raw = MutableStateFlow<AuthSession>(signedIn("A"))
        // Production exposes SDK StateFlow.map as Flow, not as StateFlow.
        val f = fixture(sessionFlow = raw.map { it })
        val statuses = recordStatuses(f)
        runCurrent()
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        raw.value = signedIn("B")
        runCurrent()
        assertFalse(VerificationStatus.Verified in statuses)
        assertEquals(listOf("A", "B"), f.requests.map { it.userId })
        f.requests.last().complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(listOf(null, VerificationStatus.Pending), statuses)
    }

    @Test
    fun `non replaying auth fails closed without leaving work for a future login`() = runTest {
        val sessions = MutableSharedFlow<AuthSession>()
        val f = fixture(sessionFlow = sessions)
        val statuses = recordStatuses(f)
        runCurrent()
        sessions.emit(signedIn("A"))
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals("Only the full auth observer remains", 1, sessions.subscriptionCount.value)
        assertEquals("No current snapshot is available from a non-replaying source", 0, f.requests.size)

        sessions.emit(signedIn("B"))
        runCurrent()
        assertEquals(1, sessions.subscriptionCount.value)
        assertEquals("Old manual work cannot start for later B", 0, f.requests.size)
        assertEquals(listOf<VerificationStatus?>(null), statuses)
    }

    @Test
    fun `a suspended auth probe is cancelled without admitting work when it later becomes readable`() = runTest {
        val raw = MutableStateFlow<AuthSession>(signedIn("A"))
        val probeReady = CompletableDeferred<Unit>()
        var activeSubscriptions = 0
        val f = fixture(sessionFlow = flow {
            val observer = activeSubscriptions++ == 0
            try {
                if (!observer) probeReady.await()
                raw.collect { emit(it) }
            } finally {
                activeSubscriptions--
            }
        })
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, activeSubscriptions)
        assertEquals(0, f.requests.size)

        // Making auth readable must not resurrect either dropped operation.
        probeReady.complete(Unit)
        runCurrent()
        assertEquals(0, f.requests.size)
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(listOf("A"), f.requests.map { it.userId })
        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `auth snapshot failure stays null and permits a deliberate retry`() = runTest {
        val raw = MutableStateFlow<AuthSession>(signedIn("A"))
        var activeSubscriptions = 0
        var probesFail = false
        val f = fixture(sessionFlow = flow {
            val observer = activeSubscriptions++ == 0
            try {
                if (!observer && probesFail) throw IOException("current auth unavailable")
                raw.collect { emit(it) }
            } finally {
                activeSubscriptions--
            }
        })
        runCurrent()
        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        probesFail = true
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, activeSubscriptions)
        assertEquals("Failed auth probe cannot admit a new fetch", 1, f.requests.size)
        assertNull(f.host.engineerStatus.value)

        probesFail = false
        f.host.refreshEngineerStatus()
        runCurrent()
        f.requests.last().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `late first A cannot overwrite reentered A in observed A B A sequence`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        val firstA = f.requests.single()
        f.session(signedIn("B"))
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A", "B", "A"), f.requests.map { it.userId })
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        firstA.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `late pre-signout A cannot overwrite same-account relogin`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        val old = f.requests.single()
        f.session(AuthSession.SignedOut)
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        old.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `newest manual refresh owns publication even when older responses return later`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(3, f.requests.size)
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        f.requests[1].completeFailure(IOException("old failure"))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
        f.requests.first().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `duplicate emitted sessions including null email do not cancel pending request`() = runTest {
        val sessions = MutableSharedFlow<AuthSession>(replay = 1)
        sessions.emit(signedIn("A"))
        val f = fixture(sessionFlow = sessions)
        runCurrent()
        sessions.emit(signedIn("A"))
        runCurrent()
        sessions.emit(signedIn("A", null))
        runCurrent()
        assertEquals(1, f.requests.size)
        assertEquals(false, f.requests.single().job.isCancelled)
        f.requests.single().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `empty and whitespace identities reject automatic and manual fetches`() = runTest {
        for (id in listOf("", " ", "\t\n")) {
            val f = fixture(signedIn(id))
            runCurrent()
            f.host.refreshEngineerStatus()
            runCurrent()
            assertEquals(emptyList<String>(), f.requests.map { it.userId })
            assertNull(f.host.engineerStatus.value)
        }
    }

    @Test
    fun `Unknown cancels pending work rejects manual refresh and drops late result`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        val old = f.requests.single()
        f.session(AuthSession.Unknown)
        runCurrent()
        assertEquals(true, old.job.isCancelled)
        f.host.refreshEngineerStatus()
        runCurrent()
        old.complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        assertEquals(1, f.requests.size)
        f.session(signedIn("B"))
        runCurrent()
        f.requests.last().complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `cooperative network request is cancelled without blocking auth collection`() = runTest {
        val f = fixture(signedIn("A"), cooperative = true)
        runCurrent()
        val old = f.requests.single()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(true, old.job.isCancelled)
        assertEquals(true, old.job.isCompleted)
        assertEquals(listOf("A", "B"), f.requests.map { it.userId })
        f.requests.last().complete(engineer("B", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }

    @Test
    fun `cleared host cannot publish a late noncooperative response`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.host.viewModelScope.cancel()
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals("Cleared host cannot open fresh network work", 1, f.requests.size)
    }

    @Test
    fun `thrown fetch failure allows later valid manual refresh`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.requests.single().result.completeExceptionally(IOException("offline"))
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        f.host.refreshEngineerStatus()
        runCurrent()
        f.requests.last().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `missing engineer row stays null and later manual refresh still works`() = runTest {
        val f = fixture(signedIn("A"))
        runCurrent()
        f.requests.single().complete(null)
        runCurrent()
        assertNull(f.host.engineerStatus.value)
        f.host.refreshEngineerStatus()
        runCurrent()
        f.requests.last().complete(engineer("A", VerificationStatus.Pending))
        runCurrent()
        assertEquals(VerificationStatus.Pending, f.host.engineerStatus.value)
    }
}
