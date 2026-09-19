package com.equipseva.app.features.auth

import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.profile.ProfileInvalidations
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.RecordingUserPrefs
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * Each transition is drained with runCurrent: an observed SignedOut separates
 * two logins of A. AuthSession has no server session id, so transitions lost to
 * an upstream StateFlow's conflation cannot be distinguished by this VM.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SessionViewModelIdentityTest {
    private val fixtures = mutableListOf<Fixture>()

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }

    @After fun tearDown() {
        fixtures.forEach { it.close() }
        Dispatchers.resetMain()
    }

    private class Fetch(val userId: String) {
        val response = CompletableDeferred<Result<Profile?>>()
        fun complete(profile: Profile?) { response.complete(Result.success(profile)) }
    }

    private class Fixture(
        initialSession: AuthSession,
        val prefs: RecordingUserPrefs,
    ) {
        val auth = FakeAuthRepository(initialSession)
        val invalidations = ProfileInvalidations()
        var signOutResult: Result<Unit> = Result.success(Unit)
        // Unlike StateFlow, this emits exact duplicate SignedIn values too.
        val sessions = MutableSharedFlow<AuthSession>(replay = 1, extraBufferCapacity = 16)
            .also { it.tryEmit(initialSession) }
        val authRepository = object : AuthRepository by auth {
            override val sessionState = sessions
            override suspend fun signOut(): Result<Unit> {
                auth.signOut()
                return signOutResult
            }
        }
        val fetches = mutableListOf<Fetch>()
        val profileRepository = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } coAnswers {
                val fetch = Fetch(firstArg())
                fetches += fetch
                // Model a dependency that swallows cancellation. Cancel-and-
                // replace alone must not admit its eventual result or finally.
                withContext(NonCancellable) { fetch.response.await() }
            }
        }
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { refresh() } returns Unit
        }
        val cleanup = mockk<SignOutCleanup> {
            coEvery { wipeLocalUserState() } returns Unit
        }
        lateinit var vm: SessionViewModel

        fun start() {
            vm = SessionViewModel(authRepository, profileRepository, prefs.mock, registrar, cleanup, invalidations)
        }

        fun session(session: AuthSession) { check(sessions.tryEmit(session)) }

        fun close() {
            vm.viewModelScope.cancel()
            fetches.forEach { it.response.complete(Result.failure(CancellationException("Test finished"))) }
        }
    }

    private fun fixture(
        initialSession: AuthSession = signedIn("A"),
        prefs: RecordingUserPrefs = RecordingUserPrefs.create(),
        configure: Fixture.() -> Unit = {},
    ): Fixture = Fixture(initialSession, prefs).also {
        fixtures += it
        it.configure()
        it.start()
    }

    private fun TestScope.recordStates(fixture: Fixture): MutableList<SessionState> =
        mutableListOf<SessionState>().also { states ->
            backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
                fixture.vm.state.collect { states += it }
            }
        }

    @Test fun `same account signs out and signs in again with a fresh bootstrap`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)

        f.session(AuthSession.SignedOut)
        runCurrent()
        assertEquals(SessionState.SignedOut, f.vm.state.value)
        assertFalse(f.vm.profileBaseV2Done.value)
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A", "A"), f.fetches.map { it.userId })
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "hospital_admin", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        coVerify(exactly = 2) { f.registrar.refresh() }
    }

    @Test fun `duplicate signed in and email changes do not refetch the same login`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        f.session(AuthSession.SignedIn("A", "new@test.invalid"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        coVerify(exactly = 1) { f.registrar.refresh() }
        assertEquals(SessionState.Ready("A", "new@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `transient unknown retains the login and validated snapshot`() = runTest {
        val f = fixture()
        val states = recordStates(f)
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        val writes = f.prefs.writeEvents.toList()
        f.session(AuthSession.Unknown)
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.vm.profileBaseV2Done.value)
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        assertEquals(1, f.fetches.size)
        assertEquals(writes, f.prefs.writeEvents)
        assertFalse(states.contains(SessionState.SignedOut))
    }

    @Test fun `profile resolving during transient unknown is retained for the same login`() = runTest {
        val f = fixture()
        runCurrent()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `replacement account cannot render cached role or onboarding while fetching`() = runTest {
        val f = fixture()
        val states = recordStates(f)
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer"))
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertFalse(f.vm.profileBaseV2Done.value)
        assertTrue(states.none { it is SessionState.Ready && it.userId == "B" })
        f.fetches.last().complete(profile("B", "hospital_admin", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        assertTrue(states.none { it is SessionState.Ready && it.userId == "B" })
    }

    private fun staleCompletion(sameAccount: Boolean, result: Result<Profile?>) = runTest {
        val f = fixture()
        val states = recordStates(f)
        val messages = mutableListOf<String>()
        backgroundScope.launch { f.vm.messages.collect { messages += it } }
        runCurrent()
        val oldFetch = f.fetches.single()
        if (sameAccount) {
            f.session(AuthSession.SignedOut)
            runCurrent()
        }
        val replacement = if (sameAccount) "A" else "B"
        f.session(signedIn(replacement))
        runCurrent()
        assertEquals(listOf("A", replacement), f.fetches.map { it.userId })
        val writesBeforeOldResult = f.prefs.writeEvents.toList()
        oldFetch.response.complete(result)
        runCurrent()
        assertEquals(writesBeforeOldResult, f.prefs.writeEvents)
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertFalse(f.vm.profileBaseV2Done.value)
        assertTrue(messages.isEmpty())
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        coVerify(exactly = 2) { f.registrar.refresh() }
        assertEquals(0, f.auth.signOutCount)
        f.fetches.last().complete(profile(replacement, "hospital_admin", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding(replacement, "$replacement@test.invalid", "hospital_admin"), f.vm.state.value)
        assertTrue(states.none { it is SessionState.Ready })
    }

    @Test fun `late A success cannot publish into B`() =
        staleCompletion(false, Result.success(profile("A", "engineer")))

    @Test fun `late first A success cannot publish into a second A login`() =
        staleCompletion(true, Result.success(profile("A", "engineer")))

    @Test fun `late missing A cannot delete B`() = staleCompletion(false, Result.success(null))

    @Test fun `late missing first A cannot delete a second A login`() = staleCompletion(true, Result.success(null))

    @Test fun `late inactive A cannot delete B`() =
        staleCompletion(false, Result.success(profile("A", active = false)))

    @Test fun `late inactive first A cannot delete a second A login`() =
        staleCompletion(true, Result.success(profile("A", active = false)))

    @Test fun `late failed A cannot drop the replacement loading fence`() =
        staleCompletion(false, Result.failure(IOException("offline")))

    @Test fun `direct A to B to A invalidates both earlier requests`() = runTest {
        val f = fixture()
        runCurrent()
        val firstA = f.fetches.single()
        f.session(signedIn("B"))
        runCurrent()
        val b = f.fetches.last()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A", "B", "A"), f.fetches.map { it.userId })
        val writes = f.prefs.writeEvents.toList()
        firstA.complete(profile("A", "engineer"))
        b.complete(null)
        runCurrent()
        assertEquals(writes, f.prefs.writeEvents)
        assertEquals(SessionState.Loading, f.vm.state.value)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        f.fetches.last().complete(profile("A", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `missing result during unknown waits for same login before deletion effects`() = runTest {
        val f = fixture()
        runCurrent()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.fetches.single().complete(null)
        runCurrent()
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        assertTrue(f.prefs.writeEvents.isEmpty())
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        coVerify(exactly = 1) { f.cleanup.wipeLocalUserState() }
        assertEquals(1, f.auth.signOutCount)
    }

    @Test fun `inactive result held during unknown is discarded when B replaces A`() = runTest {
        val f = fixture()
        runCurrent()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.fetches.single().complete(profile("A", active = false))
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        assertTrue(f.prefs.writeEvents.isEmpty())
        assertEquals(SessionState.Loading, f.vm.state.value)
    }

    private fun queuedResponseBeforeAuthObserver(result: Result<Profile?>) = runTest {
        val f = fixture()
        val messages = mutableListOf<String>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            f.vm.messages.collect { messages += it }
        }
        runCurrent()
        // Queue the profile continuation FIRST, then publish B upstream. The
        // auth observer has not run yet when that continuation resumes.
        f.fetches.single().response.complete(result)
        f.session(signedIn("B"))
        runCurrent()
        assertTrue(f.prefs.writeEvents.isEmpty())
        assertTrue(messages.isEmpty())
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
    }

    @Test fun `queued success checks live auth before the auth observer processes B`() =
        queuedResponseBeforeAuthObserver(Result.success(profile("A", "engineer")))

    @Test fun `queued deletion checks live auth before the auth observer processes B`() =
        queuedResponseBeforeAuthObserver(Result.success(null))

    @Test fun `queued sign out preference continuation cannot clear B onboarding cache`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture {
            coEvery { prefs.mock.clearActiveRole() } coAnswers {
                prefs.activeRole.value = null
                // Mirrors the suspension after synchronous SecurePrefs clear.
                release.await()
            }
        }
        try {
            runCurrent()
            f.fetches.single().complete(profile("A"))
            runCurrent()
            f.session(AuthSession.SignedOut)
            runCurrent()
            val writes = f.prefs.v2OnboardingWrites.toList()
            release.complete(Unit)
            f.session(signedIn("B"))
            runCurrent()
            assertEquals(writes, f.prefs.v2OnboardingWrites)
            assertEquals(SessionState.Loading, f.vm.state.value)
        } finally { release.complete(Unit) }
    }

    @Test fun `newer refresh wins when the older request completes last`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer", onboarded = false))
        runCurrent()
        f.vm.refreshNow()
        runCurrent()
        val oldRefresh = f.fetches.last()
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        val writes = f.prefs.writeEvents.toList()
        oldRefresh.complete(profile("A", "engineer", onboarded = false))
        runCurrent()
        assertEquals(writes, f.prefs.writeEvents)
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        assertTrue(f.vm.profileBaseV2Done.value)
    }

    @Test fun `superseded bootstrap finally cannot clear a newer refresh loading fence`() = runTest {
        val f = fixture()
        runCurrent()
        val bootstrap = f.fetches.single()
        f.vm.refreshNow()
        runCurrent()
        assertEquals(2, f.fetches.size)
        bootstrap.response.complete(Result.failure(IOException("old request failed")))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `old missing refresh cannot sign out after a newer refresh succeeds`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        f.vm.refreshNow()
        runCurrent()
        val oldRefresh = f.fetches.last()
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        oldRefresh.complete(null)
        runCurrent()
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
    }

    @Test fun `slow token registration does not delay loading or replacement profile fetch`() = runTest {
        val token = CompletableDeferred<Unit>()
        val f = fixture(prefs = RecordingUserPrefs.create("engineer", true)) {
            coEvery { registrar.refresh() } coAnswers { withContext(NonCancellable) { token.await() } }
        }
        try {
            runCurrent()
            assertEquals(SessionState.Loading, f.vm.state.value)
            assertEquals(listOf("A"), f.fetches.map { it.userId })
            coVerify(exactly = 1) { f.registrar.refresh() }
            assertFalse(token.isCompleted)
            f.session(signedIn("B"))
            runCurrent()
            assertEquals(SessionState.Loading, f.vm.state.value)
            assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
            coVerify(exactly = 2) { f.registrar.refresh() }
            assertFalse(token.isCompleted)
            f.fetches.last().complete(profile("B", "hospital_admin", onboarded = false))
            runCurrent()
            assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        } finally {
            token.complete(Unit)
            runCurrent()
        }
    }

    @Test fun `published role cannot expose old onboarding while its setter is suspended`() = runTest {
        val published = CompletableDeferred<Unit>()
        val f = fixture(prefs = RecordingUserPrefs.create().apply {
            afterActiveRolePublication = { published.await() }
        })
        val states = recordStates(f)
        try {
            runCurrent()
            f.fetches.single().complete(profile("A"))
            runCurrent()
            assertEquals("hospital_admin", f.prefs.activeRole.value)
            assertEquals(SessionState.Loading, f.vm.state.value)
            assertTrue(states.none { it is SessionState.NeedsOnboarding })
            published.complete(Unit)
            runCurrent()
            assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
            assertTrue(states.none { it is SessionState.NeedsOnboarding })
        } finally { published.complete(Unit) }
    }

    @Test fun `account replacement cancels a cooperative role write before publication`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture(prefs = RecordingUserPrefs.create().apply {
            // This pre-publication hook is a stronger suspension boundary than
            // production SecurePrefs, and intentionally cooperates with cancel.
            beforeActiveRoleWrite = { release.await() }
        })
        try {
            runCurrent()
            f.fetches.single().complete(profile("A", "engineer"))
            runCurrent()
            f.session(signedIn("B"))
            runCurrent()
            release.complete(Unit)
            runCurrent()
            assertFalse(f.prefs.activeRoleWrites.contains("engineer"))
            assertTrue(f.prefs.v2OnboardingWrites.isEmpty())
            assertEquals(SessionState.Loading, f.vm.state.value)
            f.fetches.last().complete(profile("B", onboarded = false))
            runCurrent()
            assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        } finally { release.complete(Unit) }
    }

    @Test fun `replacement during role persistence prevents old onboarding publication`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture(prefs = RecordingUserPrefs.create().apply {
            afterActiveRolePublication = { release.await() }
        })
        try {
            runCurrent()
            f.fetches.single().complete(profile("A", "engineer"))
            runCurrent()
            f.session(signedIn("B"))
            runCurrent()
            val writes = f.prefs.writeEvents.toList()
            release.complete(Unit)
            runCurrent()
            assertEquals(writes, f.prefs.writeEvents)
            assertTrue(f.prefs.v2OnboardingWrites.isEmpty())
            assertEquals(SessionState.Loading, f.vm.state.value)
            assertFalse(f.vm.profileBaseV2Done.value)
            f.fetches.last().complete(profile("B", onboarded = false))
            runCurrent()
            assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        } finally { release.complete(Unit) }
    }

    private fun currentDeletion(profile: Profile?, expectedMessage: String) = runTest {
        val f = fixture()
        val messages = mutableListOf<String>()
        backgroundScope.launch { f.vm.messages.collect { messages += it } }
        runCurrent()
        f.fetches.single().complete(profile)
        runCurrent()
        assertEquals(listOf(expectedMessage), messages)
        coVerify(exactly = 1) { f.cleanup.wipeLocalUserState() }
        assertEquals(1, f.auth.signOutCount)
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.vm.refreshNow()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        assertEquals(1, f.auth.signOutCount)
    }

    @Test fun `current missing account still cleans up and signs out`() =
        currentDeletion(null, "Your account is no longer active. Sign in again.")

    @Test fun `current inactive account still cleans up and signs out`() =
        currentDeletion(profile("A", active = false), "This account was deleted. Contact support to restore it.")

    @Test fun `cleanup admitted by old login cannot later sign out a replacement`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture {
            // The real cleanup swallows cancellation. Its already-started
            // global writes remain outside A1; only the subsequent signOut
            // admission is asserted here.
            coEvery { cleanup.wipeLocalUserState() } coAnswers {
                withContext(NonCancellable) { release.await() }
            }
        }
        try {
            runCurrent()
            f.fetches.single().complete(null)
            runCurrent()
            coVerify(exactly = 1) { f.cleanup.wipeLocalUserState() }
            f.session(signedIn("B"))
            runCurrent()
            assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
            release.complete(Unit)
            runCurrent()
            assertEquals(0, f.auth.signOutCount)
            assertEquals(SessionState.Loading, f.vm.state.value)
            f.fetches.last().complete(profile("B"))
            runCurrent()
            assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        } finally { release.complete(Unit) }
    }

    @Test fun `cold offline bootstrap cannot trust device global cached identity`() = runTest {
        val f = fixture(prefs = RecordingUserPrefs.create("engineer", true))
        val states = recordStates(f)
        runCurrent()
        f.fetches.single().response.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(states.none { it is SessionState.Ready || it is SessionState.NeedsOnboarding })
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `offline refresh retains the current validated snapshot without deletion`() = runTest {
        val f = fixture()
        val messages = mutableListOf<String>()
        backgroundScope.launch { f.vm.messages.collect { messages += it } }
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        val ready = f.vm.state.value
        val writes = f.prefs.writeEvents.toList()
        f.vm.refreshNow()
        runCurrent()
        assertEquals(ready, f.vm.state.value)
        f.fetches.last().response.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(ready, f.vm.state.value)
        assertEquals(writes, f.prefs.writeEvents)
        assertTrue(messages.isEmpty())
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
    }

    @Test fun `role and onboarding changes advance only after explicit current login refresh`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", onboarded = false).copy(roleConfirmed = false))
        runCurrent()
        assertEquals(SessionState.NeedsRole("A", "A@test.invalid"), f.vm.state.value)
        f.prefs.mock.setActiveRole("hospital_admin")
        runCurrent()
        // Preferences have no owner or generation. The role writer must ask
        // for a refresh; accepting its bare emission would also accept A's
        // delayed cached role after B has resolved (A2/A4 call-site work).
        assertEquals(SessionState.NeedsRole("A", "A@test.invalid"), f.vm.state.value)
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
    }

    @Test fun `late unowned preference emission cannot overwrite B resolved snapshot`() = runTest {
        val f = fixture()
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        f.fetches.last().complete(profile("B", onboarded = false))
        runCurrent()
        f.prefs.activeRole.value = "engineer"
        f.prefs.v2OnboardingComplete.value = true
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        assertFalse(f.vm.profileBaseV2Done.value)
    }

    @Test fun `blank auth user id never fetches registers or trusts cached identity`() = runTest {
        val f = fixture(AuthSession.SignedIn("  ", null), RecordingUserPrefs.create("engineer", true))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.fetches.isEmpty())
        coVerify(exactly = 0) { f.registrar.refresh() }
    }

    @Test fun `foreign profile result cannot publish or revoke the requested login`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("B", active = false))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.prefs.writeEvents.isEmpty())
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.auth.signOutCount)
    }

    @Test fun `engineer base onboarding stays distinct from incomplete payout`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer").copy(hasEngineerPayoutComplete = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "engineer"), f.vm.state.value)
        assertTrue(f.vm.profileBaseV2Done.value)
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
    }

    @Test fun `view model cancellation blocks non cooperative late profile effects`() = runTest {
        val f = fixture()
        runCurrent()
        f.vm.viewModelScope.cancel()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        assertTrue(f.prefs.writeEvents.isEmpty())
        assertEquals(SessionState.Loading, f.vm.state.value)
    }

    @Test fun `role mirror IO failure stays gated and can retry without crashing`() = runTest {
        var failWrite = true
        val f = fixture {
            coEvery { prefs.mock.setActiveRole(any()) } coAnswers {
                if (failWrite) throw IOException("SecurePrefs unavailable")
                prefs.activeRole.value = firstArg()
            }
        }
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        failWrite = false
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `onboarding mirror IO failure after role publication stays gated until retry`() = runTest {
        var failWrite = true
        val f = fixture {
            coEvery { prefs.mock.setV2OnboardingComplete(any()) } coAnswers {
                if (failWrite) throw IOException("DataStore unavailable")
                prefs.v2OnboardingComplete.value = firstArg()
            }
        }
        val states = recordStates(f)
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        assertEquals("hospital_admin", f.prefs.activeRole.value)
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(states.none { it is SessionState.NeedsOnboarding || it is SessionState.Ready })
        failWrite = false
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `signed out preference IO failure does not stop a new login`() = runTest {
        val f = fixture(AuthSession.SignedOut) {
            coEvery { prefs.mock.clearActiveRole() } throws IOException("DataStore unavailable")
        }
        runCurrent()
        assertEquals(SessionState.SignedOut, f.vm.state.value)
        f.session(signedIn("B"))
        runCurrent()
        f.fetches.single().complete(profile("B"))
        runCurrent()
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `refresh mirror IO failure retains only the validated same login snapshot`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        coEvery { f.prefs.mock.setActiveRole("engineer") } throws IOException("SecurePrefs unavailable")
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `preference cancellation never promotes a profile and a new refresh can recover`() = runTest {
        val f = fixture {
            coEvery { prefs.mock.setActiveRole(any()) } throws CancellationException("Cancelled write")
        }
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.prefs.v2OnboardingWrites.isEmpty())
        coEvery { f.prefs.mock.setActiveRole(any()) } returns Unit
        f.vm.refreshNow()
        runCurrent()
        f.fetches.last().complete(profile("A"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `immediate main dispatcher can construct and resolve initial session safely`() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        val f = fixture {
            coEvery { profileRepository.fetchById("A") } returns Result.success(profile("A"))
        }
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        assertTrue(f.vm.profileBaseV2Done.value)
    }

    @Test fun `refresh is a no op without an observed signed in login`() = runTest {
        val f = fixture(AuthSession.SignedOut)
        runCurrent()
        f.vm.refreshNow()
        runCurrent()
        assertTrue(f.fetches.isEmpty())
        assertEquals(SessionState.SignedOut, f.vm.state.value)
    }

    @Test fun `presentation retains same login during unknown but resets observed relogin`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer"))
        runCurrent()
        val ready = f.vm.presentation.value
        assertEquals(f.vm.state.value, ready.state)
        assertTrue(ready.baseProfileComplete)
        f.session(AuthSession.Unknown)
        runCurrent()
        val unknown = f.vm.presentation.value
        assertEquals(ready.owner, unknown.owner)
        assertEquals(ready.state, unknown.retainedState)
        assertEquals(SessionState.Loading, unknown.state)
        assertTrue(unknown.resolvingAuth)
        f.session(AuthSession.SignedOut)
        runCurrent()
        assertNull(f.vm.presentation.value.owner)
        assertNull(f.vm.presentation.value.retainedState)
        f.session(signedIn("A"))
        runCurrent()
        assertNotEquals(ready.owner, f.vm.presentation.value.owner)
        assertNull(f.vm.presentation.value.retainedState)
        assertFalse(f.vm.presentation.value.baseProfileComplete)
    }

    @Test fun `saved role invalidates old ready and failed fetch remains recoverable`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        val owner = f.vm.presentation.value.owner
        f.vm.refreshAfterProfileSave()
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.vm.presentation.value.profileLoading)
        assertEquals(owner, f.vm.presentation.value.owner)
        f.fetches.last().response.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.vm.presentation.value.profileFailed)
        assertFalse(f.vm.presentation.value.profileLoading)
        f.vm.refreshAfterProfileSave()
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "engineer"), f.vm.state.value)
        assertFalse(f.vm.presentation.value.profileFailed)
    }

    @Test fun `repository role invalidation refreshes root without any child callback`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A").copy(roleConfirmed = false))
        runCurrent()
        f.invalidations.invalidate()
        runCurrent()
        assertEquals(SessionState.NeedsRole("A", "A@test.invalid"), f.vm.state.value)
        assertEquals(2, f.fetches.size)
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
    }

    @Test fun `unowned late invalidation refreshes B without dropping its validated host`() = runTest {
        val f = fixture()
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        f.fetches.last().complete(profile("B"))
        runCurrent()
        val before = f.vm.presentation.value
        f.invalidations.invalidate()
        runCurrent()
        assertEquals(before.state, f.vm.presentation.value.state)
        assertEquals(before.owner, f.vm.presentation.value.owner)
        assertEquals("B", f.fetches.last().userId)
        f.fetches.last().response.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(before.state, f.vm.presentation.value.state)
        assertEquals(before.owner, f.vm.presentation.value.owner)
    }

    @Test fun `invalidation during unknown rejects the older request before auth resumes`() = runTest {
        val f = fixture()
        runCurrent()
        val old = f.fetches.single()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.invalidations.invalidate()
        runCurrent()
        old.complete(profile("A", "engineer"))
        runCurrent()
        assertNull(f.vm.presentation.value.retainedState)
        assertTrue(f.prefs.writeEvents.isEmpty())
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(2, f.fetches.size)
        assertTrue(f.prefs.writeEvents.isEmpty())
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `pending invalidation cannot restore old login on replacement`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.invalidations.invalidate()
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        assertNull(f.vm.presentation.value.retainedState)
        f.fetches.last().complete(profile("B", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `queued invalidation before subscription cannot be dropped`() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        val f = fixture {
            coEvery { profileRepository.fetchById(any()) } coAnswers {
                val fetch = Fetch(firstArg())
                fetches += fetch
                // Main.immediate starts bootstrap before init registers its
                // invalidation collector. drop(1) would lose this notification.
                if (fetches.size == 1) invalidations.invalidate()
                withContext(NonCancellable) { fetch.response.await() }
            }
        }
        assertEquals(2, f.fetches.size)
        f.fetches.first().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertTrue(f.prefs.writeEvents.isEmpty())
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
    }

    @Test fun `signout gates immediately and ignores duplicate taps and late fetch`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture {
            coEvery { cleanup.wipeLocalUserState() } coAnswers { release.await() }
        }
        try {
            runCurrent()
            val old = f.fetches.single()
            f.vm.signOutFromGate()
            f.vm.signOutFromGate()
            runCurrent()
            assertEquals(SessionState.Loading, f.vm.state.value)
            assertFalse(f.vm.presentation.value.profileLoading)
            assertTrue(f.vm.presentation.value.signingOut)
            old.complete(profile("A"))
            runCurrent()
            assertTrue(f.prefs.writeEvents.isEmpty())
            coVerify(exactly = 1) { f.cleanup.wipeLocalUserState() }
            release.complete(Unit)
            runCurrent()
            assertEquals(1, f.auth.signOutCount)
            // The server call returned but SignedOut has not been observed.
            // A retained callback cannot start cleanup/signout a second time.
            f.vm.signOutFromGate()
            runCurrent()
            assertEquals(1, f.auth.signOutCount)
            coVerify(exactly = 1) { f.cleanup.wipeLocalUserState() }
            f.session(AuthSession.SignedOut)
            runCurrent()
            assertEquals(SessionState.SignedOut, f.vm.state.value)
            assertNull(f.vm.presentation.value.owner)
        } finally { release.complete(Unit) }
    }

    @Test fun `failed signout leaves recovery and can be retried`() = runTest {
        val f = fixture { signOutResult = Result.failure(IOException("offline")) }
        runCurrent()
        f.vm.signOutFromGate()
        runCurrent()
        assertTrue(f.vm.presentation.value.profileFailed)
        assertFalse(f.vm.presentation.value.signingOut)
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.signOutResult = Result.success(Unit)
        f.vm.signOutFromGate()
        runCurrent()
        assertEquals(2, f.auth.signOutCount)
        f.session(AuthSession.SignedOut)
        runCurrent()
        assertEquals(SessionState.SignedOut, f.vm.state.value)
    }

    @Test fun `captured root actions cannot mutate replacement or second login of same user`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        val firstA = f.vm.presentation.value.owner
        f.session(signedIn("B"))
        runCurrent()
        f.fetches.last().complete(profile("B"))
        runCurrent()
        f.vm.refreshAfterProfileSave(firstA)
        f.vm.signOutFromGate(firstA)
        runCurrent()
        assertEquals(2, f.fetches.size)
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        assertEquals(0, f.auth.signOutCount)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        f.session(signedIn("A"))
        runCurrent()
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        f.vm.refreshAfterProfileSave(firstA)
        f.vm.signOutFromGate(firstA)
        f.vm.refreshAfterProfileSave(null)
        f.vm.signOutFromGate(null)
        runCurrent()
        assertEquals(3, f.fetches.size)
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
        assertEquals(0, f.auth.signOutCount)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
    }

    @Test fun `signout dependency cancellation releases owned progress for retry`() = runTest {
        val f = fixture { signOutResult = Result.failure(CancellationException("Cancelled request")) }
        runCurrent()
        f.vm.signOutFromGate()
        runCurrent()
        assertFalse(f.vm.presentation.value.signingOut)
        assertTrue(f.vm.presentation.value.profileFailed)
        f.signOutResult = Result.success(Unit)
        f.vm.signOutFromGate()
        runCurrent()
        assertEquals(2, f.auth.signOutCount)
        f.session(AuthSession.SignedOut)
        runCurrent()
        assertEquals(SessionState.SignedOut, f.vm.state.value)
    }

    @Test fun `live unknown before observer runs cannot arm UI mutations for later`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A"))
        runCurrent()
        val ready = f.vm.presentation.value
        // Queue UI admission first, then change upstream before either the UI
        // coroutine or the auth observer has run. Snapshot still says Ready.
        f.vm.refreshAfterProfileSave(ready.owner)
        f.vm.signOutFromGate(ready.owner)
        f.session(AuthSession.Unknown)
        assertEquals(ready, f.vm.presentation.value)
        runCurrent()
        assertEquals(ready.state, f.vm.presentation.value.retainedState)
        assertFalse(f.vm.presentation.value.signingOut)
        assertEquals(1, f.fetches.size)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(ready.state, f.vm.state.value)
        assertEquals(1, f.fetches.size)
        assertEquals(0, f.auth.signOutCount)
    }

    @Test fun `old explicit signout cleanup completion cannot sign out replacement`() = runTest {
        val release = CompletableDeferred<Unit>()
        val f = fixture {
            coEvery { cleanup.wipeLocalUserState() } coAnswers {
                withContext(NonCancellable) { release.await() }
            }
        }
        try {
            runCurrent()
            f.vm.signOutFromGate()
            runCurrent()
            f.session(signedIn("B"))
            runCurrent()
            release.complete(Unit)
            runCurrent()
            assertEquals(0, f.auth.signOutCount)
            f.fetches.last().complete(profile("B"))
            runCurrent()
            assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        } finally { release.complete(Unit) }
    }

    companion object {
        private fun signedIn(userId: String) = AuthSession.SignedIn(userId, "$userId@test.invalid")

        private fun profile(
            userId: String,
            role: String = "hospital_admin",
            onboarded: Boolean = true,
            active: Boolean = true,
        ) = Profile(
            id = userId, email = "$userId@test.invalid", phone = if (onboarded) "+919999999999" else null,
            fullName = "Test $userId", avatarUrl = null,
            role = UserRole.entries.single { it.storageKey == role }, rawRoleKey = role,
            roleConfirmed = true, onboardingCompleted = onboarded, isActive = active,
            organizationId = null, organizationName = null, organizationCity = null, organizationState = null,
            activeRole = UserRole.entries.single { it.storageKey == role }, activeRoleKey = role,
            state = if (onboarded) "Telangana" else null,
            district = if (onboarded) "Hyderabad" else null,
        )
    }
}
