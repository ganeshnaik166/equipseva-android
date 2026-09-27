package com.equipseva.app.features.auth

import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/** Observed identity boundaries only; AuthSession has no opaque SDK login ID. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SessionIdentityBoundaryTest {
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

    private class Fixture(initial: AuthSession = signedIn("A")) {
        val sessions = MutableSharedFlow<AuthSession>(replay = 1, extraBufferCapacity = 16)
            .also { check(it.tryEmit(initial)) }
        val fakeAuth = FakeAuthRepository()
        val auth: AuthRepository = object : AuthRepository by fakeAuth {
            override val sessionState = sessions
        }
        val fetches = mutableListOf<Fetch>()
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } coAnswers {
                val fetch = Fetch(firstArg())
                fetches += fetch
                // A cancelled request that still returns must not publish.
                withContext(NonCancellable) { fetch.response.await() }
            }
        }
        val tokenGate = CompletableDeferred<Unit>()
        var blockToken = false
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { refresh() } coAnswers {
                if (blockToken) withContext(NonCancellable) { tokenGate.await() }
            }
        }
        val cleanup = mockk<SignOutCleanup> {
            coEvery { wipeLocalUserState() } returns Unit
        }
        val role = MutableStateFlow<String?>("engineer")
        val onboarded = MutableStateFlow(true)
        val writes = mutableListOf<String>()
        val clearGate = CompletableDeferred<Unit>()
        var blockClear = false
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns role
            every { v2OnboardingComplete } returns onboarded
            every { observeTourSeen() } returns MutableStateFlow(true)
            coEvery { setActiveRole(any()) } coAnswers {
                val value = firstArg<String>()
                writes += "role:$value"
                role.value = value
            }
            coEvery { clearActiveRole() } coAnswers {
                if (blockClear) withContext(NonCancellable) { clearGate.await() }
                writes += "clear"
                role.value = null
            }
            coEvery { setV2OnboardingComplete(any()) } coAnswers {
                val value = firstArg<Boolean>()
                writes += "onboarded:$value"
                onboarded.value = value
            }
        }
        val vm = SessionViewModel(auth, profiles, prefs, registrar, cleanup)

        fun session(next: AuthSession) { check(sessions.tryEmit(next)) }
        fun close() {
            vm.viewModelScope.cancel()
            tokenGate.complete(Unit)
            clearGate.complete(Unit)
            fetches.forEach { it.response.complete(Result.failure(CancellationException("fixture closed"))) }
        }
    }

    private fun fixture(initial: AuthSession = signedIn("A")) = Fixture(initial).also { fixtures += it }

    @Test fun `observed sign out then same account creates a fresh gate and fetch`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)

        f.session(AuthSession.SignedOut)
        runCurrent()
        assertEquals(SessionState.SignedOut, f.vm.state.value)
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A", "A"), f.fetches.map { it.userId })
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "hospital_admin", onboarded = false))
        runCurrent()
        assertEquals(SessionState.NeedsOnboarding("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
        coVerify(exactly = 2) { f.registrar.refresh() }
    }

    @Test fun `new account is fetched without waiting for the old noncooperative response`() = runTest {
        val f = fixture()
        runCurrent()
        val a = f.fetches.single()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("B", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        val writes = f.writes.toList()
        a.complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(writes, f.writes)
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `late missing account cannot wipe or sign out replacement`() = runTest {
        val f = fixture()
        runCurrent()
        val a = f.fetches.single()
        f.session(signedIn("B"))
        runCurrent()
        a.complete(null)
        runCurrent()
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.fakeAuth.signOutCount)
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("B", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `late inactive account cannot wipe or sign out replacement`() = runTest {
        val f = fixture()
        runCurrent()
        val a = f.fetches.single()
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        a.complete(profile("A", "engineer", active = false))
        runCurrent()
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(0, f.fakeAuth.signOutCount)
        assertEquals(SessionState.Loading, f.vm.state.value)
    }

    @Test fun `observed A B A discards the first two results`() = runTest {
        val f = fixture()
        runCurrent()
        val firstA = f.fetches.single()
        f.session(signedIn("B"))
        runCurrent()
        val b = f.fetches.last()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A", "B", "A"), f.fetches.map { it.userId })
        val writes = f.writes.toList()
        firstA.complete(profile("A", "engineer"))
        b.complete(null)
        runCurrent()
        assertEquals(writes, f.writes)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `old first login cannot publish into a second login of the same account`() = runTest {
        val f = fixture()
        runCurrent()
        val first = f.fetches.single()
        f.session(AuthSession.SignedOut)
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(2, f.fetches.size)
        val writes = f.writes.toList()
        first.complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(writes, f.writes)
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `token registration cannot hold up a profile fetch or replacement login`() = runTest {
        val f = fixture(AuthSession.SignedOut)
        f.blockToken = true
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(listOf("A"), f.fetches.map { it.userId })
        f.session(signedIn("B"))
        runCurrent()
        assertEquals(listOf("A", "B"), f.fetches.map { it.userId })
        f.tokenGate.complete(Unit)
    }

    @Test fun `unknown blank identity duplicates and manual refresh do not invent a login`() = runTest {
        val f = fixture(AuthSession.SignedOut)
        runCurrent()
        f.vm.refreshNow()
        f.session(AuthSession.Unknown)
        runCurrent()
        f.vm.refreshNow()
        f.session(signedIn(" "))
        runCurrent()
        f.vm.refreshNow()
        runCurrent()
        assertTrue(f.fetches.isEmpty())
        assertEquals(SessionState.Loading, f.vm.state.value)

        f.session(signedIn("A"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        f.session(signedIn("A"))
        f.session(AuthSession.SignedIn("A", "new@test.invalid"))
        runCurrent()
        assertEquals(1, f.fetches.size)
        f.vm.refreshNow()
        runCurrent()
        assertEquals(2, f.fetches.size)
        f.fetches.first().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "new@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `cached role and wrong profile identity never open the root gate`() = runTest {
        val f = fixture()
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.fetches.single().complete(profile("B", "hospital_admin"))
        runCurrent()
        assertFalse(f.vm.state.value is SessionState.Ready)
        assertTrue(f.vm.presentation.value.verificationFailed)
        coVerify(exactly = 0) { f.cleanup.wipeLocalUserState() }
    }

    @Test fun `failed initial fetch stays gated and a manual retry can recover`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().response.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        assertTrue(f.vm.presentation.value.verificationFailed)
        f.vm.refreshNow()
        runCurrent()
        assertFalse(f.vm.presentation.value.verificationFailed)
        assertEquals(2, f.fetches.size)
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `same login resume remains covered until fresh role is checked`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)

        f.session(AuthSession.Unknown)
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        assertEquals(2, f.fetches.size)
        assertTrue(f.vm.presentation.value.resolvingAuth)
        f.fetches.last().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
        assertFalse(f.vm.presentation.value.resolvingAuth)
    }

    @Test fun `foreground refresh covers a prior role while demotion is pending`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "hospital_admin"))
        runCurrent()
        f.vm.refreshNow()
        // Root callbacks read the synchronous snapshot before the derived
        // presentation StateFlow and Compose have delivered the cover.
        assertTrue(f.vm.currentPresentation().resolvingAuth)
        runCurrent()
        assertEquals(2, f.fetches.size)
        assertTrue(f.vm.presentation.value.resolvingAuth)
        f.fetches.last().complete(profile("A", "engineer", confirmed = false))
        runCurrent()
        assertTrue(f.vm.state.value is SessionState.NeedsRole)
        assertFalse(f.vm.presentation.value.resolvingAuth)
    }

    @Test fun `signup profile commit requests a server confirmed retry`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer", confirmed = false))
        runCurrent()
        assertTrue(f.vm.state.value is SessionState.NeedsRole)
        f.vm.refreshNow() // SignUp effect calls this; local role remains untrusted.
        runCurrent()
        assertEquals(2, f.fetches.size)
        assertTrue(f.vm.state.value is SessionState.NeedsRole)
        f.fetches.last().complete(profile("A", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "hospital_admin"), f.vm.state.value)
    }

    @Test fun `late noncooperative sign out mirror clear cannot win over B profile write`() = runTest {
        val f = fixture()
        runCurrent()
        f.fetches.single().complete(profile("A", "engineer"))
        runCurrent()
        assertEquals(SessionState.Ready("A", "A@test.invalid", "engineer"), f.vm.state.value)
        f.blockClear = true
        f.session(AuthSession.SignedOut)
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        f.fetches.last().complete(profile("B", "hospital_admin"))
        runCurrent()
        assertEquals(SessionState.Loading, f.vm.state.value)
        f.clearGate.complete(Unit)
        runCurrent()
        assertEquals("hospital_admin", f.role.value)
        assertEquals(SessionState.Ready("B", "B@test.invalid", "hospital_admin"), f.vm.state.value)
        assertEquals("role:hospital_admin", f.writes.last { it.startsWith("role:") })
    }

    private companion object {
        fun signedIn(id: String) = AuthSession.SignedIn(id, "$id@test.invalid")

        fun profile(
            id: String,
            role: String,
            onboarded: Boolean = true,
            active: Boolean = true,
            confirmed: Boolean = true,
        ) = Profile(
            id = id,
            email = "$id@test.invalid",
            phone = if (onboarded) "555" else null,
            fullName = id,
            avatarUrl = null,
            role = null,
            rawRoleKey = role,
            roleConfirmed = confirmed,
            onboardingCompleted = onboarded,
            isActive = active,
            organizationId = null,
            organizationName = null,
            organizationCity = null,
            organizationState = null,
            state = if (onboarded) "Telangana" else null,
            district = if (onboarded) "Hyderabad" else null,
        )
    }
}
