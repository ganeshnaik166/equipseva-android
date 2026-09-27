package com.equipseva.app.navigation

import android.content.Intent
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A3-02 desired security contract, written before the replay fence. These
 * assertions failed against the original unowned router/host channels. An
 * admitted route is still untrusted with respect to its account.
 * The destination screen's server authorization is a separate gate.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkHostReplayIsolationTest {
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val loginA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val loginA2 = LoginTicketSnapshot(userA, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    private val loginB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val accountA = AuthSession.SignedIn(userA, "a@example.test")
    private val accountB = AuthSession.SignedIn(userB, "b@example.test")
    private val accountARoute = Routes.repairJobDetailRoute("RPR-00027")
    private val accountBRoute = Routes.repairJobDetailRoute("RPR-00028")

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class TicketHarness(initial: LoginTicketSnapshot?) {
        var current: LoginTicketSnapshot? = initial
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers { current }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun router_buffer_from_A_cannot_replay_when_host_starts_under_B() = runTest {
        val tickets = TicketHarness(loginA)
        val auth = FakeAuthRepository(accountA)
        // No host is collecting yet. The ingress boundary must retain A's
        // ownership or discard this route; B may never inherit it.
        tickets.router.dispatch(routeIntent(accountARoute))
        tickets.current = loginB
        auth.setSession(accountB)

        val host = host(tickets, auth)
        advanceUntilIdle()

        assertNull("B inherited A's pre-host router buffer", host.nextRouteOrNull())
    }

    @Test fun host_buffer_from_A_cannot_replay_after_direct_A_to_B_replacement() = runTest {
        val tickets = TicketHarness(loginA)
        val auth = FakeAuthRepository(accountA)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle() // Move the event into the host's one-shot queue.
        tickets.current = loginB
        auth.setSession(accountB)
        advanceUntilIdle()

        assertNull("B inherited A's host buffer", host.nextRouteOrNull())
    }

    @Test fun host_buffer_from_A_cannot_replay_after_sign_out_and_same_account_return() = runTest {
        val tickets = TicketHarness(loginA)
        val auth = FakeAuthRepository(accountA)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        tickets.current = null
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        tickets.current = loginA2
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("A's new login inherited its earlier login's event", host.nextRouteOrNull())
    }

    @Test fun unknown_session_retires_the_previous_login_buffer() = runTest {
        val tickets = TicketHarness(loginA)
        val auth = FakeAuthRepository(accountA)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        tickets.current = null
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        // Even the same ticket may not recover an event after observed Unknown.
        tickets.current = loginA
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("Unknown retained an event from an unverified login", host.nextRouteOrNull())
    }

    @Test fun signed_out_ingress_is_not_saved_for_the_next_login() = runTest {
        val tickets = TicketHarness(null)
        val auth = FakeAuthRepository(AuthSession.SignedOut)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        advanceUntilIdle()
        tickets.current = loginA
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("A inherited a route received with no verified owner", host.nextRouteOrNull())
    }

    @Test fun fresh_route_for_the_same_observed_login_is_delivered_once() = runTest {
        val tickets = TicketHarness(loginB)
        val auth = FakeAuthRepository(accountB)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountBRoute, userB))
        advanceUntilIdle()

        assertEquals(accountBRoute, host.nextRouteOrNull())
        assertNull("A single ingress produced a duplicate navigation", host.nextRouteOrNull())
    }

    @Test fun unobserved_new_login_ticket_retires_queued_event_for_same_user() = runTest {
        val tickets = TicketHarness(loginA)
        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        tickets.current = loginA2 // AuthSession emitted no boundary.

        assertNull("An unobserved new login inherited the prior ticket's route", host.nextRouteOrNull())
    }

    @Test fun consumed_event_is_rejected_at_final_navigation_boundary_after_account_change() = runTest {
        val tickets = TicketHarness(loginA)
        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        val event = host.events.first()
        assertEquals(accountARoute, (event as DeepLinkHost.VerifiedEvent.OpenRoute).route)
        tickets.current = loginB

        assertFalse("Already-consumed A route can still navigate under B", host.isCurrent(event))
    }

    @Test fun observed_A_to_B_to_A_retires_the_first_A_event() = runTest {
        val tickets = TicketHarness(loginA)
        val auth = FakeAuthRepository(accountA)
        val host = host(tickets, auth)
        advanceUntilIdle()

        tickets.router.dispatch(routeIntent(accountARoute))
        tickets.current = loginB
        auth.setSession(accountB)
        advanceUntilIdle()
        tickets.current = loginA
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("The first A generation survived A to B to A", host.nextRouteOrNull())
        tickets.router.dispatch(routeIntent(accountARoute))
        assertEquals(accountARoute, host.nextRouteOrNull())
    }

    private fun routeIntent(route: String, recipient: String? = userA): Intent =
        Intent().putExtra(DeepLinkRouter.EXTRA_ROUTE, route).apply {
            if (recipient != null) putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)
        }

    private fun host(tickets: TicketHarness, auth: FakeAuthRepository): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(tickets.router, prefs, auth, engineers, tickets.source).also {
            hosts += it
            registrations += it.registerRouterSink()
        }
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? =
        withTimeoutOrNull(50) {
            (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
        }
}
