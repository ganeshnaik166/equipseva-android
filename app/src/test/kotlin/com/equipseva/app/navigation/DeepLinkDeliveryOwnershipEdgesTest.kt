package com.equipseva.app.navigation

import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.RecordingUserPrefs
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CoroutineStart
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

/** Additional proposed S3 cases. Draft outside repo: not compiled or run. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeepLinkDeliveryOwnershipEdgesTest {
    private val oldRoute = Routes.repairJobDetailRoute("RPR-1")
    private val freshRoute = Routes.repairJobDetailRoute("RPR-2")
    private fun login(id: String) = AuthSession.SignedIn(id, null)

    @Before fun setup() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun teardown() { Dispatchers.resetMain() }

    private fun host(auth: FakeAuthRepository, router: DeepLinkRouter): DeepLinkHost = DeepLinkHost(
        router, RecordingUserPrefs.create().mock, auth,
        mockk<EngineerRepository> { coEvery { fetchByUserId(any()) } returns Result.success(null) },
    )

    @Test fun `a router admission reads signed out before its full observer catches up`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch(start = CoroutineStart.UNDISPATCHED) { router.events.toList(received) }
        auth.setSession(AuthSession.SignedOut)
        router.dispatchRoute(oldRoute, null) // deliberately no runCurrent between auth and dispatch
        runCurrent()
        assertTrue(received.isEmpty())
        auth.setSession(login("B"))
        runCurrent()
        router.dispatchRoute(freshRoute, "B")
        runCurrent()
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(freshRoute, "B")), received)
    }

    @Test fun `a host delivery reads signed out before its observers catch up`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        val host = host(auth, router)
        try {
            runCurrent()
            router.dispatchRoute(oldRoute, null)
            runCurrent() // parked in the host's separate channel
            auth.setSession(AuthSession.SignedOut)
            val received = mutableListOf<DeepLinkHost.VerifiedEvent>()
            backgroundScope.launch(start = CoroutineStart.UNDISPATCHED) { host.events.toList(received) }
            assertTrue("synchronous consumer must not receive a stale envelope", received.isEmpty())
            runCurrent()
            auth.setSession(login("A"))
            runCurrent()
            router.dispatchRoute(freshRoute, null)
            runCurrent()
            assertEquals(listOf(DeepLinkHost.VerifiedEvent.OpenRoute(freshRoute)), received)
        } finally { host.viewModelScope.cancel() }
    }

    @Test fun `later unknown retires a host-buffered tap even if the same account returns`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        val host = host(auth, router)
        try {
            runCurrent()
            router.dispatchRoute(oldRoute, null)
            runCurrent()
            auth.setSession(AuthSession.Unknown)
            runCurrent()
            auth.setSession(login("A"))
            runCurrent()
            val received = mutableListOf<DeepLinkHost.VerifiedEvent>()
            backgroundScope.launch { host.events.toList(received) }
            runCurrent()
            assertTrue(received.isEmpty())
            router.dispatchRoute(freshRoute, null)
            runCurrent()
            assertEquals(listOf(DeepLinkHost.VerifiedEvent.OpenRoute(freshRoute)), received)
        } finally { host.viewModelScope.cancel() }
    }

    @Test fun `explicit clear retires host-buffered taps until a new observed login`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        val host = host(auth, router)
        try {
            runCurrent()
            router.dispatchRoute(oldRoute, null)
            runCurrent()
            router.clear()
            router.dispatchRoute(oldRoute, null) // the SDK may retain A during sign-out cleanup
            val received = mutableListOf<DeepLinkHost.VerifiedEvent>()
            backgroundScope.launch { host.events.toList(received) }
            runCurrent()
            assertTrue(received.isEmpty())
            auth.setSession(AuthSession.SignedOut)
            runCurrent()
            auth.setSession(login("A"))
            runCurrent()
            router.dispatchRoute(freshRoute, null)
            runCurrent()
            assertEquals(listOf(DeepLinkHost.VerifiedEvent.OpenRoute(freshRoute)), received)
        } finally { host.viewModelScope.cancel() }
    }

    @Test fun `initial unresolved queue keeps at most first thirty two taps in order`() = runTest {
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        val routes = (1..100).map { Routes.repairJobDetailRoute("RPR-$it") }
        routes.forEach { router.dispatchRoute(it, null) }
        auth.setSession(login("A"))
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertEquals(routes.take(32), received.map { (it as DeepLinkRouter.Event.OpenRoute).route })
        router.dispatchRoute(freshRoute, null)
        runCurrent()
        assertEquals(freshRoute, (received.last() as DeepLinkRouter.Event.OpenRoute).route)
    }
}
