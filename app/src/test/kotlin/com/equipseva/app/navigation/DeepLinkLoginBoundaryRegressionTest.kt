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

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeepLinkLoginBoundaryRegressionTest {
    private val oldJob = Routes.repairJobDetailRoute("RPR-00040")
    private val freshJob = Routes.repairJobDetailRoute("RPR-00041")
    private fun login(id: String, email: String? = null) = AuthSession.SignedIn(id, email)

    @Before fun setup() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun teardown() { Dispatchers.resetMain() }

    @Test fun `a later unresolved session never adopts a tap into a replacement login`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        auth.setSession(AuthSession.Unknown)
        runCurrent()
        router.dispatchRoute(oldJob, null)
        auth.setSession(login("B"))
        runCurrent()
        router.dispatchRoute(freshJob, null)
        val events = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(events) }
        runCurrent()
        assertEquals(listOf(freshJob), events.map { (it as DeepLinkRouter.Event.OpenRoute).route })
    }

    @Test fun `an observed A to B to A boundary retires an undelivered A tap`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(oldJob, null)
        auth.setSession(login("B"))
        runCurrent()
        auth.setSession(login("A"))
        runCurrent()
        router.dispatchRoute(freshJob, null)
        val events = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(events) }
        runCurrent()
        assertEquals(listOf(freshJob), events.map { (it as DeepLinkRouter.Event.OpenRoute).route })
    }

    @Test fun `a tap already buffered by a host expires at an observed login boundary`() = runTest {
        val auth = FakeAuthRepository(login("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success(null)
        }
        val host = DeepLinkHost(router, RecordingUserPrefs.create().mock, auth, engineers)
        try {
            runCurrent()
            router.dispatchRoute(oldJob, null)
            runCurrent() // router -> host, but the navigation collector is not mounted
            auth.setSession(login("B"))
            runCurrent()
            auth.setSession(login("A"))
            runCurrent()
            val events = mutableListOf<DeepLinkHost.VerifiedEvent>()
            backgroundScope.launch { host.events.toList(events) }
            runCurrent()
            assertTrue("The host's own buffer must not bypass ownership", events.isEmpty())
            router.dispatchRoute(freshJob, null)
            runCurrent()
            assertEquals(listOf(DeepLinkHost.VerifiedEvent.OpenRoute(freshJob)), events)
        } finally {
            host.viewModelScope.cancel()
        }
    }

    @Test fun `initial resolution and email-only updates still deliver legitimate taps`() = runTest {
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(oldJob, null)
        auth.setSession(login("A"))
        runCurrent()
        auth.setSession(login("A", "synthetic@example.invalid"))
        runCurrent()
        router.dispatchRoute(freshJob, "A")
        val events = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(events) }
        runCurrent()
        assertEquals(listOf(oldJob, freshJob), events.map { (it as DeepLinkRouter.Event.OpenRoute).route })
    }

    @Test fun `blank identity cannot hold a tap for a later real account`() = runTest {
        val auth = FakeAuthRepository(login(" "))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(oldJob, null)
        auth.setSession(AuthSession.Unknown)
        runCurrent()
        router.dispatchRoute(oldJob, null)
        auth.setSession(login("B"))
        runCurrent()
        val events = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(events) }
        runCurrent()
        assertTrue(events.isEmpty())
    }
}
