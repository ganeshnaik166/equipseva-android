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
 * Regressions for an Activity recreated while its exact restoring tap is still held.
 * No OS-delivery token or decoded JWT is trusted as authorization. An in-process
 * transfer requires the old opaque Activity owner, the latest router ingress,
 * the current Intent's delivery identity and the unchanged SDK/storage login
 * ticket. The saved Bundle identity can be stale after a later onNewIntent and
 * does not authorize transfer. A process death has no old owner, so its saved
 * marker alone cannot transfer a tap.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkActivityRecreationTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val route = Routes.repairJobDetailRoute("RPR-00027")
    private val notificationOne = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    private val notificationTwo = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class Harness {
        var sdkTicket: LoginTicketSnapshot? = null
        var provisionalTicket: LoginTicketSnapshot? = ticketA
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers { sdkTicket }
            every { provisionalStoredTicketDuringInitializing() } answers { provisionalTicket }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun delayed_old_SignedOut_does_not_erase_B_tap_held_by_Unknown_host() = runTest {
        val h = Harness().apply { provisionalTicket = ticketB }
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.router.dispatch(notificationTap(notificationOne, userB), owner)
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        assertNull("A provisional witness cannot navigate", host.nextRouteOrNull())

        h.sdkTicket = ticketB
        h.provisionalTicket = null
        auth.setSession(AuthSession.SignedIn(userB, null))
        advanceUntilIdle()
        assertEquals("A delayed old logout erased B's exact pending tap", route, host.nextRouteOrNull())
        assertNull("B's tap navigated twice", host.nextRouteOrNull())
    }

    @Test fun real_terminal_SignedOut_without_a_witness_retires_Unknown_hosts_tap() = runTest {
        val h = Harness().apply { provisionalTicket = ticketB }
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.router.dispatch(notificationTap(notificationOne, userB), owner)
        h.provisionalTicket = null
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        h.sdkTicket = ticketB
        auth.setSession(AuthSession.SignedIn(userB, null))
        advanceUntilIdle()
        assertNull("A terminal failure leaked its old tap into a later login", host.nextRouteOrNull())
    }

    @Test fun same_in_process_notification_recreation_transfers_once_to_new_owner() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        val identity = savedIdentity(tap)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(tap, oldOwner)
        assertFalse(RestoredTaskIngress.shouldDispatch(savedAfter(tap), Intent(tap)))

        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, identity, Intent(tap),
        ))
        h.router.endActivity(oldOwner)
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("The destroyed owner claimed a transferred tap", h.router.takeStartupFor(oldOwner, userA))
        assertEquals(route, h.router.takeStartupFor(newOwner, userA)?.route)
        assertNull("A recreated tap navigated twice", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun old_Activity_teardown_precedes_new_onCreate_and_retained_tap_transfers_once() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(tap, oldOwner)

        // Android destroys the old Activity during configuration recreation
        // before the replacement can inspect its restored Intent. The owner
        // itself is retained in process, not written into savedInstanceState.
        h.router.endActivityForRecreation(oldOwner)
        assertNull("The destroyed Activity retained claim authority", h.router.takeStartupFor(oldOwner, userA))
        assertFalse(RestoredTaskIngress.shouldDispatch(savedAfter(tap), Intent(tap)))

        assertTrue(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertEquals(route, h.router.takeStartupFor(newOwner, userA)?.route)
        assertNull("Configuration recreation delivered the tap twice", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun old_Activity_teardown_then_changed_ticket_cannot_transfer() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(tap, oldOwner)
        h.router.endActivityForRecreation(oldOwner)
        h.provisionalTicket = ticketB

        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("A later return to A revived its old tap", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun same_route_App_Link_is_not_a_unique_delivery_identity_for_transfer() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val link = Intent(Intent.ACTION_VIEW, Uri.parse("https://equipseva.com/job/RPR-00027"))
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(link, oldOwner)
        h.router.endActivityForRecreation(oldOwner)
        assertFalse(RestoredTaskIngress.shouldDispatch(savedAfter(link), Intent(link)))

        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(link), Intent(link),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("The same route could be a separate App Link tap", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun same_route_with_different_notification_identity_does_not_transfer() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val first = notificationTap(notificationOne, userA)
        val second = notificationTap(notificationTwo, userA)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(first, oldOwner)
        // A different restored Intent is not proof it arrived after the last
        // save; an in-process onNewIntent handles genuinely live new taps.
        assertFalse(RestoredTaskIngress.shouldDispatch(savedAfter(first), second))

        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(first), second,
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("A different tap inherited the old handoff", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun wrong_previous_owner_cannot_steal_the_pending_restoration() {
        val h = Harness()
        val realOwner = DeepLinkRouter.LaunchOwner()
        val unrelatedOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        h.router.beginActivity(realOwner)
        h.router.dispatchStartup(tap, realOwner)

        assertFalse(h.router.transferPendingToRestoredActivity(
            unrelatedOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("An unrelated Activity stole the tap", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun changed_login_ticket_cannot_transfer_an_old_pending_tap() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(tap, oldOwner)
        h.provisionalTicket = ticketB

        assertFalse(h.router.transferPendingToRestoredActivity(
            oldOwner, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("A later return to A claimed the old transfer", h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun process_death_without_a_previous_owner_cannot_transfer() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        val tap = notificationTap(notificationOne, userA)
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(tap, oldOwner)

        assertFalse(h.router.transferPendingToRestoredActivity(
            null, newOwner, savedIdentity(tap), Intent(tap),
        ))
        h.sdkTicket = ticketA
        h.provisionalTicket = null
        assertNull("A saved identity alone resurrected a process-dead tap", h.router.takeStartupFor(newOwner, userA))
    }

    private fun notificationTap(id: String, recipient: String): Intent = Intent()
        .setData(Uri.parse("equipseva-internal-notification://tap/$id"))
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)

    private fun savedAfter(intent: Intent): Bundle = Bundle().also {
        RestoredTaskIngress.record(it, intent)
    }

    private fun savedIdentity(intent: Intent): String {
        val saved = savedAfter(intent)
        val key = saved.keySet().single()
        return requireNotNull(saved.getString(key))
    }

    private fun host(h: Harness, auth: FakeAuthRepository): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(h.router, prefs, auth, engineers, h.source).also { hosts += it }
    }

    private fun register(host: DeepLinkHost, owner: DeepLinkRouter.LaunchOwner) {
        registrations += host.registerRouterSink(owner)
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? = withTimeoutOrNull(50) {
        (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
    }
}
