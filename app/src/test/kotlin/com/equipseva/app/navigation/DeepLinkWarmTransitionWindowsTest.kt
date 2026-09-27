package com.equipseva.app.navigation

import android.app.Application
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
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
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
 * Desired A3-02 behavior at two late SDK restoration windows. These are
 * synthetic, offline tests of local navigation only. A stored ticket may hold
 * a tap while Initializing; it may never authorize delivery without the exact
 * authenticated SDK ticket. The first same-ticket assertions are intentional
 * RED targets until both loss windows are addressed.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkWarmTransitionWindowsTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val routeA = Routes.repairJobDetailRoute("RPR-00027")
    private val routeB = Routes.repairJobDetailRoute("RPR-00028")
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class TicketHarness {
        var initializing = false
        var sdkTicket: LoginTicketSnapshot? = ticketA
        var storedTicket: LoginTicketSnapshot? = ticketA
        var afterNextCurrentRead: (() -> Unit)? = null

        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers {
                val snapshot = sdkTicket.takeUnless { initializing }
                val transition = afterNextCurrentRead
                afterNextCurrentRead = null
                transition?.invoke()
                snapshot
            }
            every { provisionalStoredTicketDuringInitializing() } answers {
                storedTicket.takeIf { initializing }
            }
        }
        val router = DeepLinkRouter(source)

        fun pauseOnSameStoredTicket() {
            initializing = true
            sdkTicket = null
            storedTicket = ticketA
        }

        fun restore(ticket: LoginTicketSnapshot) {
            initializing = false
            sdkTicket = ticket
            storedTicket = ticket
        }
    }

    @Test fun startup_claim_is_not_lost_when_SDK_pauses_between_take_and_host_ack() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle() // Host observes A before its router sink mounts.
        h.router.dispatchStartup(push(routeA, userA), owner)

        // takeStartupFor sees authenticated A and removes the one-slot handoff;
        // immediately afterward acceptRoute sees Initializing and rejects it.
        h.afterNextCurrentRead = h::pauseOnSameStoredTicket
        registrations += host.registerRouterSink(owner)
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        assertNull("The stored ticket navigated before SDK authentication", host.nextRouteOrNull())

        h.restore(ticketA)
        auth.setSession(AuthSession.SignedIn(userA, "restored@example.test"))
        advanceUntilIdle()
        assertEquals("A startup tap was consumed before host acknowledgement", routeA, host.nextRouteOrNull())
        assertNull("A startup tap navigated twice", host.nextRouteOrNull())
    }

    @Test fun startup_claim_never_replays_after_a_different_account_restores() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        h.router.dispatchStartup(push(routeA, userA), owner)
        h.afterNextCurrentRead = h::pauseOnSameStoredTicket
        registrations += host.registerRouterSink(owner)
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()

        h.restore(ticketB)
        auth.setSession(AuthSession.SignedIn(userB, null))
        advanceUntilIdle()
        assertNull("B inherited a startup tap captured for A", host.nextRouteOrNull())

        h.router.dispatch(push(routeB, userB), owner)
        assertEquals("A fresh B tap must still work", routeB, host.nextRouteOrNull())
    }

    @Test fun buffered_host_event_waits_through_temporary_SDK_Initializing() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        registrations += host.registerRouterSink(owner)
        h.router.dispatch(push(routeA, userA), owner) // Verified event is buffered.

        // The UI collector runs while the SDK has already entered Initializing,
        // but before the auth flow's Unknown callback is observed. A filter that
        // receives and discards the event here loses an otherwise valid tap.
        h.pauseOnSameStoredTicket()
        val pendingNavigation = backgroundScope.async { host.events.first() }
        runCurrent()
        assertFalse("A stored ticket alone navigated", pendingNavigation.isCompleted)

        h.restore(ticketA)
        auth.setSession(AuthSession.SignedIn(userA, "restored@example.test"))
        runCurrent()
        val delivered = withTimeoutOrNull(100) { pendingNavigation.await() }
        assertEquals("The channel consumed A's event while SDK was Initializing",
            routeA, (delivered as? DeepLinkHost.VerifiedEvent.OpenRoute)?.route)
        assertNull("The channel delivered A twice", host.nextRouteOrNull())
    }

    @Test fun buffered_A_event_survives_observed_Unknown_for_the_same_stored_ticket() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        registrations += host.registerRouterSink(owner)
        h.router.dispatch(push(routeA, userA), owner) // Verified A is buffered.

        // This ordering differs from the preceding test: the host observes
        // Unknown before the UI collector wakes. The exact A storage witness
        // describes the same SDK restoration, so Unknown alone cannot turn
        // this already verified tap into a later-account replay.
        h.pauseOnSameStoredTicket()
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        val pendingNavigation = backgroundScope.async { host.events.first() }
        runCurrent()
        assertFalse("A stored ticket alone navigated", pendingNavigation.isCompleted)

        h.restore(ticketA)
        auth.setSession(AuthSession.SignedIn(userA, "restored@example.test"))
        runCurrent()
        val delivered = withTimeoutOrNull(100) { pendingNavigation.await() }
        assertEquals("Unknown discarded a buffered route for the exact restored A login",
            routeA, (delivered as? DeepLinkHost.VerifiedEvent.OpenRoute)?.route)
        assertNull("The restored A route navigated twice", host.nextRouteOrNull())
    }

    @Test fun observed_A_to_B_before_Unknown_never_resurrects_the_old_A_channel_event() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        registrations += host.registerRouterSink(owner)
        h.router.dispatch(push(routeA, userA), owner) // A event is buffered.

        // B is an observed login generation, not merely an SDK restoration
        // pause. Even if encrypted storage later names A again, the first A
        // event belongs to the generation that preceded B.
        h.restore(ticketB)
        auth.setSession(AuthSession.SignedIn(userB, "b@example.test"))
        advanceUntilIdle()
        h.pauseOnSameStoredTicket()
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        val pendingNavigation = backgroundScope.async { host.events.first() }
        runCurrent()
        assertFalse("An old A route navigated under Unknown", pendingNavigation.isCompleted)

        h.restore(ticketA)
        auth.setSession(AuthSession.SignedIn(userA, "a-return@example.test"))
        runCurrent()
        assertNull("The pre-B A event replayed when A returned",
            withTimeoutOrNull(100) { pendingNavigation.await() })
        pendingNavigation.cancelAndJoin()

        h.router.dispatch(push(routeA, userA), owner)
        assertEquals("A fresh route after A returns must still work", routeA, host.nextRouteOrNull())
    }

    @Test fun buffered_host_event_cannot_cross_from_A_to_B_after_temporary_Initializing() = runTest {
        val h = TicketHarness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        registrations += host.registerRouterSink(owner)
        h.router.dispatch(push(routeA, userA), owner)

        h.pauseOnSameStoredTicket()
        val pendingNavigation = backgroundScope.async { host.events.first() }
        runCurrent()
        assertFalse("A stored ticket alone navigated", pendingNavigation.isCompleted)

        h.restore(ticketB)
        auth.setSession(AuthSession.SignedIn(userB, null))
        runCurrent()
        assertNull("B received A's queued route", withTimeoutOrNull(100) { pendingNavigation.await() })
        pendingNavigation.cancelAndJoin()

        h.router.dispatch(push(routeB, userB), owner)
        assertEquals("A fresh B tap must still work", routeB, host.nextRouteOrNull())
    }

    private fun push(route: String, recipient: String): Intent = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)

    private fun host(h: TicketHarness, auth: FakeAuthRepository): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(h.router, prefs, auth, engineers, h.source).also { hosts += it }
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? = withTimeoutOrNull(50) {
        (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
    }
}
