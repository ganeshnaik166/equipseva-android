package com.equipseva.app.navigation

import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.RecordingUserPrefs
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * A3-02, host side — [DeepLinkHost] forwards a router event only when the
 * event's stamped owner is the login that is live RIGHT NOW. Uses a REAL
 * [DeepLinkRouter] (not a mock) so the stamp → gate contract is exercised
 * end to end. Only the router-collector section of the host is under test;
 * its engineerStatus section (another agent's) is left at its null default.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeepLinkHostOwnerGateTest {

    private val job = Routes.repairJobDetailRoute("RPR-00040")

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun signedIn(id: String) = AuthSession.SignedIn(userId = id, email = null)

    private fun host(auth: FakeAuthRepository, router: DeepLinkRouter): DeepLinkHost {
        val engineers = mockk<EngineerRepository> { coEvery { fetchByUserId(any()) } returns Result.success(null) }
        return DeepLinkHost(
            router = router,
            userPrefs = RecordingUserPrefs.create().mock,
            authRepository = auth,
            engineerRepository = engineers,
        )
    }

    @Test fun `event stamped for the live owner is forwarded`() = runTest {
        val auth = FakeAuthRepository(signedIn("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        val host = host(auth, router)
        val received = mutableListOf<DeepLinkHost.VerifiedEvent>()
        backgroundScope.launch { host.events.toList(received) }
        router.dispatchRoute(job, recipientUserId = null)
        runCurrent()
        assertEquals(listOf(DeepLinkHost.VerifiedEvent.OpenRoute(job)), received)
        host.viewModelScope.cancel()
    }

    @Test fun `event stamped for a previous owner is dropped by the new owner's host`() = runTest {
        // A dispatches; before any MAIN collects, the account switches to B.
        // The router's own sign-out clear normally handles this; the host gate is
        // the second line of defence for an event that slipped through (e.g. an
        // auth source that never emits SignedOut between two logins).
        val auth = FakeAuthRepository(signedIn("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null) // stamped A, buffered
        auth.setSession(signedIn("B"))                     // no SignedOut in between
        runCurrent()
        val host = host(auth, router)                      // B's MAIN mounts
        val received = mutableListOf<DeepLinkHost.VerifiedEvent>()
        backgroundScope.launch { host.events.toList(received) }
        runCurrent()
        assertTrue("A's event must not navigate inside B's session: $received", received.isEmpty())
        host.viewModelScope.cancel()
    }
}
