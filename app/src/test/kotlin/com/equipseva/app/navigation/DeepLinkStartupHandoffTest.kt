package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
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
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Desired A3-02 cold-start contract. Only MainActivity's one-shot startup
 * ingress may wait for the first host; an ordinary dispatch without a sink
 * still drops. SDK login tickets, not exported Intent extras, own the handoff.
 * These synthetic tests do not assert server authorization for a route.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkStartupHandoffTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val loginA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val loginA2 = LoginTicketSnapshot(userA, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    private val loginB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val accountA = AuthSession.SignedIn(userA, "a@example.test")
    private val accountB = AuthSession.SignedIn(userB, "b@example.test")
    private val routeOne = Routes.repairJobDetailRoute("RPR-00027")
    private val routeTwo = Routes.repairJobDetailRoute("RPR-00028")
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

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
            every { provisionalStoredTicketDuringInitializing() } returns null
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun pre_host_push_for_A_reaches_A_once() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertEquals(routeOne, host.nextRouteOrNull())
        assertNull("Startup handoff navigated twice", host.nextRouteOrNull())
    }

    @Test fun pre_host_raw_FCM_sender_keys_reach_the_matching_account() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(Intent()
            .putExtra("notification_id", "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
            .putExtra("kind", NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED)
            .putExtra("repair_job_id", "RPR-00027")
            .putExtra("user_id", userA))

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertEquals(routeOne, host.nextRouteOrNull())
        assertNull(host.nextRouteOrNull())
    }

    @Test fun pre_host_https_app_link_reaches_A_without_a_push_recipient() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(Intent().apply {
            data = Uri.parse("https://equipseva.com/job/RPR-00027")
        })

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertEquals(routeOne, host.nextRouteOrNull())
        assertNull(host.nextRouteOrNull())
    }

    @Test fun stale_push_recipient_never_enters_the_startup_handoff() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userB))

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertNull("B-targeted push navigated under A", host.nextRouteOrNull())
        tickets.router.dispatch(pushIntent(routeTwo, userA))
        assertEquals(routeTwo, host.nextRouteOrNull())
    }

    @Test fun A_startup_tap_does_not_follow_direct_A_to_B_replacement() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        tickets.current = loginB

        val host = host(tickets, FakeAuthRepository(accountB))
        advanceUntilIdle()
        register(host)

        assertNull("B inherited A's startup tap", host.nextRouteOrNull())
    }

    @Test fun A_startup_tap_does_not_follow_an_unobserved_new_A_login() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        tickets.current = null
        tickets.current = loginA2

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertNull("A's new session inherited an old startup tap", host.nextRouteOrNull())
    }

    @Test fun startup_without_an_SDK_ticket_is_never_saved_for_later_login() = runTest {
        val tickets = TicketHarness(null)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        tickets.current = loginA

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertNull("Signed-out startup intent replayed after login", host.nextRouteOrNull())
    }

    @Test fun initializing_without_an_SDK_ticket_never_gives_the_tap_to_later_A() = runTest {
        val tickets = TicketHarness(null)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        val host = host(tickets, auth)
        register(host)
        advanceUntilIdle()

        tickets.current = loginA
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("Unowned startup tap followed a later login", host.nextRouteOrNull())
    }

    @Test fun initial_Unknown_may_settle_to_A_with_the_same_SDK_ticket() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(tickets, auth)
        register(host)
        advanceUntilIdle() // Host has observed initial Unknown, not a prior login boundary.

        auth.setSession(accountA)
        advanceUntilIdle()

        assertEquals("Host initialization lost the valid startup tap", routeOne, host.nextRouteOrNull())
        assertNull(host.nextRouteOrNull())
    }

    @Test fun observed_SignedOut_retires_pending_startup_even_if_ticket_recurs() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(tickets, auth)
        register(host)
        advanceUntilIdle()

        tickets.current = null
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        tickets.current = loginA // Deliberately reuse the ticket to isolate the observed boundary.
        auth.setSession(accountA)
        advanceUntilIdle()

        assertNull("Observed sign-out retained the startup tap", host.nextRouteOrNull())
    }

    @Test fun ordinary_dispatch_without_sink_still_drops_before_and_after_a_mount() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatch(pushIntent(routeOne, userA))
        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        val first = register(host)
        assertNull("Ordinary pre-host dispatch was buffered", host.nextRouteOrNull())

        first.close()
        tickets.router.dispatch(pushIntent(routeOne, userA))
        register(host)
        assertNull("Ordinary dispatch after sink disposal was buffered", host.nextRouteOrNull())

        tickets.router.dispatch(pushIntent(routeTwo, userA))
        assertEquals(routeTwo, host.nextRouteOrNull())
    }

    @Test fun a_later_ordinary_intent_before_mount_retires_the_older_startup_tap() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        tickets.router.dispatch(pushIntent(routeTwo, userA)) // A newer onNewIntent while no host exists.

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertNull("An older startup route survived a later intent", host.nextRouteOrNull())
        tickets.router.dispatch(pushIntent(routeTwo, userA))
        assertEquals(routeTwo, host.nextRouteOrNull())
    }

    @Test fun second_pre_host_startup_intent_replaces_the_first() = runTest {
        val tickets = TicketHarness(loginA)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA))
        tickets.router.dispatchStartup(pushIntent(routeTwo, userA))

        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host)

        assertEquals(routeTwo, host.nextRouteOrNull())
        assertNull("First startup tap survived replacement", host.nextRouteOrNull())
    }

    @Test fun new_Activity_launch_waits_for_its_own_host_instead_of_the_old_Activity_sink() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA), newOwner)
        assertNull("Older Activity consumed the new launch", oldHost.nextRouteOrNull())

        val newHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertEquals(routeOne, newHost.nextRouteOrNull())
        assertNull(newHost.nextRouteOrNull())
    }

    @Test fun old_host_reregistration_and_close_cannot_steal_or_retire_new_launch() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        val firstOldRegistration = register(oldHost, oldOwner)

        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA), newOwner)
        firstOldRegistration.close()
        register(oldHost, oldOwner) // Old Compose host remounts before the new graph.
        tickets.router.endActivity(oldOwner)
        assertNull("Old host stole the newer Activity tap", oldHost.nextRouteOrNull())

        val newHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertEquals(routeOne, newHost.nextRouteOrNull())
        assertNull(newHost.nextRouteOrNull())
    }

    @Test fun ordinary_intents_are_delivered_only_to_their_own_Activity() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.router.beginActivity(newOwner)
        val newHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(newHost, newOwner)
        tickets.router.dispatch(pushIntent(routeOne, userA), newOwner)
        assertNull("New Activity intent entered old graph", oldHost.nextRouteOrNull())
        assertEquals(routeOne, newHost.nextRouteOrNull())

        tickets.router.dispatch(pushIntent(routeTwo, userA), oldOwner)
        assertEquals(routeTwo, oldHost.nextRouteOrNull())
        assertNull("Old Activity intent entered new graph", newHost.nextRouteOrNull())
    }

    @Test fun destroyed_Activity_cannot_navigate_its_previously_queued_route() = runTest {
        val tickets = TicketHarness(loginA)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        val host = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host, owner)
        tickets.router.dispatch(pushIntent(routeOne, userA), owner)

        tickets.router.endActivity(owner)
        assertNull("Destroyed Activity still navigated a queued route", host.nextRouteOrNull())
    }

    @Test fun old_A_hosts_Unknown_does_not_retire_new_B_Activity_tap() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldAuth = FakeAuthRepository(accountA)
        val oldHost = host(tickets, oldAuth)
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.current = loginB
        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userB), newOwner)
        oldAuth.setSession(AuthSession.Unknown)
        advanceUntilIdle()

        val newHost = host(tickets, FakeAuthRepository(accountB))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertNull(oldHost.nextRouteOrNull())
        assertEquals(routeOne, newHost.nextRouteOrNull())
        assertNull(newHost.nextRouteOrNull())
    }

    @Test fun old_A_hosts_SignedOut_does_not_retire_new_B_Activity_tap() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldAuth = FakeAuthRepository(accountA)
        val oldHost = host(tickets, oldAuth)
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.current = loginB
        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userB), newOwner)
        oldAuth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()

        val newHost = host(tickets, FakeAuthRepository(accountB))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertNull(oldHost.nextRouteOrNull())
        assertEquals(routeOne, newHost.nextRouteOrNull())
        assertNull(newHost.nextRouteOrNull())
    }

    @Test fun real_SDK_ticket_loss_retires_new_B_tap_even_when_old_A_host_observes_it() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldAuth = FakeAuthRepository(accountA)
        val oldHost = host(tickets, oldAuth)
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.current = loginB
        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userB), newOwner)
        tickets.current = null
        oldAuth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        tickets.current = loginB

        val newHost = host(tickets, FakeAuthRepository(accountB))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertNull("SDK ticket loss left a startup tap for later login", newHost.nextRouteOrNull())
    }

    @Test fun old_hosts_direct_A_to_B_replacement_retires_new_A_Activity_tap() = runTest {
        val tickets = TicketHarness(loginA)
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(oldOwner)
        val oldAuth = FakeAuthRepository(accountA)
        val oldHost = host(tickets, oldAuth)
        advanceUntilIdle()
        register(oldHost, oldOwner)

        tickets.router.beginActivity(newOwner)
        tickets.router.dispatchStartup(pushIntent(routeOne, userA), newOwner)
        tickets.current = loginB
        oldAuth.setSession(accountB) // Direct replacement, no SignedOut/Unknown event.
        advanceUntilIdle()
        tickets.current = loginA // Isolate the observed boundary with the same ticket.

        val newHost = host(tickets, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(newHost, newOwner)
        assertNull("A's tap survived an observed A→B boundary", newHost.nextRouteOrNull())
    }

    private fun pushIntent(route: String, recipient: String): Intent =
        Intent().putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
            .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)

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
        }
    }

    private fun register(
        host: DeepLinkHost,
        owner: DeepLinkRouter.LaunchOwner = DeepLinkRouter.DEFAULT_OWNER,
    ): AutoCloseable = host.registerRouterSink(owner).also {
        registrations += it
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? =
        withTimeoutOrNull(50) {
            (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
        }
}
