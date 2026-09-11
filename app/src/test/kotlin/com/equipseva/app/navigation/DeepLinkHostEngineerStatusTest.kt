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
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
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
        val sessions = MutableSharedFlow<AuthSession>()
        val f = fixture(sessionFlow = sessions)
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, sessions.subscriptionCount.value)
        sessions.emit(signedIn("A"))
        runCurrent()
        assertEquals(1, f.requests.size)
        f.requests.single().complete(engineer("A", VerificationStatus.Verified))
        runCurrent()
        assertEquals(VerificationStatus.Verified, f.host.engineerStatus.value)
    }

    @Test
    fun `manual refresh never opens a second auth subscription`() = runTest {
        val sessions = MutableSharedFlow<AuthSession>(replay = 1)
        sessions.emit(signedIn("A"))
        var subscriptions = 0
        val f = fixture(sessionFlow = flow {
            subscriptions++
            sessions.collect { emit(it) }
        })
        runCurrent()
        f.host.refreshEngineerStatus()
        runCurrent()
        assertEquals(1, subscriptions)
        assertEquals(2, f.requests.size)
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
