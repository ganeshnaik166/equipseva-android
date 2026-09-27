package com.equipseva.app.navigation

import android.content.Intent
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A3-02 desired security contract, written before the replay fence. These
 * assertions intentionally fail against the current unowned router/host
 * channels. An admitted route is still untrusted with respect to its account.
 * The destination screen's server authorization is a separate gate.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkHostReplayIsolationTest {
    private val hosts = mutableListOf<DeepLinkHost>()
    private val accountA = AuthSession.SignedIn("account-a", "a@example.test")
    private val accountB = AuthSession.SignedIn("account-b", "b@example.test")
    private val accountARoute = Routes.repairJobDetailRoute("RPR-00027")
    private val accountBRoute = Routes.repairJobDetailRoute("RPR-00028")

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    @Test fun router_buffer_from_A_cannot_replay_when_host_starts_under_B() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(accountA)
        // No host is collecting yet. The ingress boundary must retain A's
        // ownership or discard this route; B may never inherit it.
        router.dispatch(routeIntent(accountARoute))
        auth.setSession(accountB)

        val host = host(router, auth)
        advanceUntilIdle()

        assertNull("B inherited A's pre-host router buffer", host.nextRouteOrNull())
    }

    @Test fun host_buffer_from_A_cannot_replay_after_direct_A_to_B_replacement() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(accountA)
        val host = host(router, auth)
        advanceUntilIdle()

        router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle() // Move the event into the host's one-shot queue.
        auth.setSession(accountB)
        advanceUntilIdle()

        assertNull("B inherited A's host buffer", host.nextRouteOrNull())
    }

    @Test fun host_buffer_from_A_cannot_replay_after_sign_out_and_same_account_return() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(accountA)
        val host = host(router, auth)
        advanceUntilIdle()

        router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("A's new login inherited its earlier login's event", host.nextRouteOrNull())
    }

    @Test fun unknown_session_retires_the_previous_login_buffer() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(accountA)
        val host = host(router, auth)
        advanceUntilIdle()

        router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("Unknown retained an event from an unverified login", host.nextRouteOrNull())
    }

    @Test fun signed_out_ingress_is_not_saved_for_the_next_login() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(AuthSession.SignedOut)
        val host = host(router, auth)
        advanceUntilIdle()

        router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("A inherited a route received with no verified owner", host.nextRouteOrNull())
    }

    @Test fun fresh_route_for_the_same_observed_login_is_delivered_once() = runTest {
        val router = DeepLinkRouter()
        val auth = FakeAuthRepository(accountB)
        val host = host(router, auth)
        advanceUntilIdle()

        router.dispatch(routeIntent(accountBRoute))
        advanceUntilIdle()

        assertEquals(accountBRoute, host.nextRouteOrNull())
        assertNull("A single ingress produced a duplicate navigation", host.nextRouteOrNull())
    }

    private fun routeIntent(route: String): Intent =
        Intent().putExtra(DeepLinkRouter.EXTRA_ROUTE, route)

    private fun host(router: DeepLinkRouter, auth: FakeAuthRepository): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(router, prefs, auth, engineers).also(hosts::add)
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? =
        withTimeoutOrNull(50) {
            (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
        }
}
