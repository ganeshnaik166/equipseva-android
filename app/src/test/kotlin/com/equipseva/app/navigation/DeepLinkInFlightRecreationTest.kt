package com.equipseva.app.navigation

import android.app.Application
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.RestoredTaskIngress
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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Desired A3-02 behavior for an authenticated warm notification after the host
 * has queued it but before MainNavGraph has finished navigation. The old
 * Activity/collector must lose authority on configuration recreation. Only an
 * exact in-process owner, unique delivery identity, and unchanged SDK ticket
 * may move the unfinished event to the replacement Activity. Process death is
 * covered separately by DeepLinkActivityRecreationTest.
 *
 * RED seam: [DeepLinkHost.finishNavigation] should be called by MainNavGraph
 * after the final current-session check and navigation attempt. No route can
 * be transferred after that acknowledgement. These tests are synthetic and
 * make no network or device calls.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkInFlightRecreationTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val firstRoute = Routes.repairJobDetailRoute("RPR-00027")
    private val secondRoute = Routes.repairJobDetailRoute("RPR-00028")
    private val firstId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    private val secondId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class Harness {
        var sdkTicket: LoginTicketSnapshot? = ticketA
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers { sdkTicket }
            every { provisionalStoredTicketDuringInitializing() } returns null
        }
        val router = DeepLinkRouter(source)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = makeHost(router, source, auth)
    }

    @Test fun queued_warm_notification_transfers_once_when_Activity_recreates_before_collection() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(firstId, firstRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)

        h.router.dispatch(tap, oldOwner) // Host acknowledged; UI collector has not run.
        h.router.endActivityForRecreation(oldOwner)
        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        registrations += h.host.registerRouterSink(newOwner)

        assertEquals(firstRoute, h.host.nextEventOrNull()?.route)
        assertNull("The recreated notification was delivered twice", h.host.nextEventOrNull())
    }

    @Test fun old_collector_event_is_stale_after_exact_transfer_to_recreated_Activity() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(firstId, firstRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(tap, oldOwner)
        val oldEvent = requireNotNull(h.host.nextEventOrNull())
        assertTrue(h.host.isCurrent(oldEvent))

        // The event left the Channel, but the old collector has not called
        // navigate/finish. It must lose navigation authority on recreation.
        h.router.endActivityForRecreation(oldOwner)
        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        assertFalse("The old collector can navigate after owner transfer", h.host.isCurrent(oldEvent))
        registrations += h.host.registerRouterSink(newOwner)
        assertEquals(firstRoute, h.host.nextEventOrNull()?.route)
        assertNull(h.host.nextEventOrNull())
    }

    @Test fun completed_navigation_is_not_replayed_by_a_configuration_recreation() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(firstId, firstRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(tap, oldOwner)
        val completed = requireNotNull(h.host.nextEventOrNull())
        assertEquals(firstRoute, completed.route)
        h.host.finishNavigation(completed)

        h.router.endActivityForRecreation(oldOwner)
        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        registrations += h.host.registerRouterSink(newOwner)
        assertNull("Completed navigation replayed after recreation", h.host.nextEventOrNull())
    }

    @Test fun newer_warm_notification_supersedes_older_unfinished_delivery() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val older = notificationTap(firstId, firstRoute)
        val newer = notificationTap(secondId, secondRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(older, oldOwner)
        val oldEvent = requireNotNull(h.host.nextEventOrNull())
        h.router.dispatch(newer, oldOwner)
        assertFalse("An older queued event remained navigable after a newer tap", h.host.isCurrent(oldEvent))

        h.router.endActivityForRecreation(oldOwner)
        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(newer), Intent(newer),
        ))
        registrations += h.host.registerRouterSink(newOwner)
        assertEquals(secondRoute, h.host.nextEventOrNull()?.route)
        assertNull("The old notification replayed beside the newer tap", h.host.nextEventOrNull())
    }

    @Test fun warm_tap_after_last_save_transfers_using_the_retained_owner_and_current_intent() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val savedBeforeTap = notificationTap(firstId, firstRoute)
        val latestTap = notificationTap(secondId, secondRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(latestTap, oldOwner)

        // onSaveInstanceState captured A; onNewIntent subsequently installed B.
        // The in-process opaque owner and exact B Intent establish the handoff.
        h.router.endActivityForRecreation(oldOwner)
        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(savedBeforeTap), Intent(latestTap),
        ))
        registrations += h.host.registerRouterSink(newOwner)
        assertEquals(secondRoute, h.host.nextEventOrNull()?.route)
        assertNull(h.host.nextEventOrNull())
    }

    @Test fun completed_older_event_cannot_clear_a_newer_unfinished_tap() = runTest {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        val first = notificationTap(firstId, firstRoute)
        val second = notificationTap(secondId, secondRoute)
        h.router.beginActivity(owner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(owner)
        h.router.dispatch(first, owner)
        val older = requireNotNull(h.host.nextEventOrNull())
        h.router.dispatch(second, owner)
        h.host.finishNavigation(older)

        assertEquals(secondRoute, h.host.nextEventOrNull()?.route)
    }

    @Test fun sign_out_retires_unfinished_navigation_before_the_same_ticket_can_return() = runTest {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(firstId, firstRoute)
        h.router.beginActivity(owner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(owner)
        h.router.dispatch(tap, owner)
        val queued = requireNotNull(h.host.nextEventOrNull())
        h.sdkTicket = null
        h.auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        h.router.retireStartupForTerminalSession(owner)
        h.sdkTicket = ticketA

        assertFalse(h.host.isCurrent(queued))
        val replacement = DeepLinkRouter.LaunchOwner()
        h.router.endActivityForRecreation(owner)
        assertFalse(h.router.transferPendingToRestoredActivity(
            owner, replacement, savedIdentity(tap), Intent(tap),
        ))
    }

    @Test fun same_account_new_login_ticket_cannot_claim_an_old_unfinished_tap() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(firstId, firstRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(tap, oldOwner)
        h.sdkTicket = LoginTicketSnapshot(userA, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")

        h.router.endActivityForRecreation(oldOwner)
        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        registrations += h.host.registerRouterSink(newOwner)
        assertNull("A later return to the old ticket revived the route", h.host.nextEventOrNull())
    }

    @Test fun a_different_current_notification_identity_cannot_steal_the_unfinished_route() = runTest {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val original = notificationTap(firstId, firstRoute)
        val unrelated = notificationTap(secondId, secondRoute)
        h.router.beginActivity(oldOwner)
        advanceUntilIdle()
        registrations += h.host.registerRouterSink(oldOwner)
        h.router.dispatch(original, oldOwner)

        h.router.endActivityForRecreation(oldOwner)
        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(original), unrelated,
        ))
        registrations += h.host.registerRouterSink(newOwner)
        assertNull(h.host.nextEventOrNull())
    }

    private fun notificationTap(id: String, route: String): Intent = Intent()
        .setData(Uri.parse("equipseva-internal-notification://tap/$id"))
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, userA)

    private fun savedIdentity(intent: Intent): String = Bundle().also {
        RestoredTaskIngress.record(it, intent)
    }.let { saved -> requireNotNull(saved.getString(saved.keySet().single())) }

    private fun makeHost(
        router: DeepLinkRouter,
        source: LoginTicketSource,
        auth: FakeAuthRepository,
    ): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(router, prefs, auth, engineers, source).also { hosts += it }
    }

    private suspend fun DeepLinkHost.nextEventOrNull(): DeepLinkHost.VerifiedEvent.OpenRoute? =
        withTimeoutOrNull(50) { events.first() as DeepLinkHost.VerifiedEvent.OpenRoute }
}
