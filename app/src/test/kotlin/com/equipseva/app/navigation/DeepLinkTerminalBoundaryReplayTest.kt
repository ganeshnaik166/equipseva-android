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
 * MainActivity calls these router observers even without a mounted graph.
 * The ticket double mirrors LoginTicketSource: stored identity is visible only
 * while the SDK initializes, and an authenticated ticket is visible only when
 * the SDK has a parseable authenticated session. A physical stored ticket is
 * never a witness after terminal NotAuthenticated. Blank mapped SignedIn is a
 * separate invalid-identity boundary. These offline tests cover local
 * navigation, not server authorization or real process death.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkTerminalBoundaryReplayTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val routeA = Routes.repairJobDetailRoute("RPR-00027")
    private val routeB = Routes.repairJobDetailRoute("RPR-00028")
    private val firstId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    private val nextId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    private enum class SdkStatus { Initializing, Authenticated, NotAuthenticated }

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class Harness(
        var status: SdkStatus = SdkStatus.Initializing,
        var authenticatedTicket: LoginTicketSnapshot? = null,
        var physicallyStoredTicket: LoginTicketSnapshot? = null,
    ) {
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers {
                authenticatedTicket.takeIf { status == SdkStatus.Authenticated }
            }
            every { provisionalStoredTicketDuringInitializing() } answers {
                physicallyStoredTicket.takeIf { status == SdkStatus.Initializing }
            }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun signed_out_retires_pending_A_even_if_A_remains_physically_stored() {
        val h = Harness(physicallyStoredTicket = ticketA)
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(tap(firstId, routeA, userA), owner)

        // MainActivity sees SignedOut / NotAuthenticated. A may remain on disk,
        // but neither source method may expose A under this SDK status.
        h.status = SdkStatus.NotAuthenticated
        assertNull(h.source.currentTicket())
        assertNull(h.source.provisionalStoredTicketDuringInitializing())
        h.router.retireStartupForTerminalSession(owner)
        h.status = SdkStatus.Authenticated
        h.authenticatedTicket = ticketA // A returns with the same snapshot.

        assertNull("SignedOut left a pre-logout pending tap claimable",
            h.router.takeStartupFor(owner, userA))
    }

    @Test fun fresh_A_tap_after_terminal_boundary_can_still_be_claimed_once() {
        val h = Harness(physicallyStoredTicket = ticketA)
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(tap(firstId, routeA, userA), owner)
        h.status = SdkStatus.NotAuthenticated
        h.router.retireStartupForTerminalSession(owner)
        h.status = SdkStatus.Authenticated
        h.authenticatedTicket = ticketA

        h.router.dispatchStartup(tap(nextId, routeB, userA), owner)
        assertEquals(routeB, h.router.takeStartupFor(owner, userA)?.route)
        assertNull("Fresh tap was claimed twice", h.router.takeStartupFor(owner, userA))
    }

    @Test fun signed_out_retires_queued_A_when_SDK_becomes_NotAuthenticated() = runTest {
        val h = Harness(
            status = SdkStatus.Authenticated,
            authenticatedTicket = ticketA,
            physicallyStoredTicket = ticketA,
        )
        val owner = DeepLinkRouter.LaunchOwner()
        val replacement = DeepLinkRouter.LaunchOwner()
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        val oldTap = tap(firstId, routeA, userA)
        h.router.beginActivity(owner)
        advanceUntilIdle()
        registrations += host.registerRouterSink(owner)
        h.router.dispatch(oldTap, owner)
        val oldEvent = requireNotNull(host.nextEventOrNull())
        assertTrue("The test never queued A's verified event", host.isCurrent(oldEvent))

        // Both mounted host and MainActivity observe terminal logout. Physical
        // storage still has A, but the source must expose neither ticket.
        h.status = SdkStatus.NotAuthenticated
        assertNull(h.source.currentTicket())
        assertNull(h.source.provisionalStoredTicketDuringInitializing())
        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        h.router.retireStartupForTerminalSession(owner)
        h.status = SdkStatus.Authenticated
        auth.setSession(AuthSession.SignedIn(userA, null))
        advanceUntilIdle()

        h.router.endActivityForRecreation(owner)
        assertFalse("A's pre-logout in-flight tap transferred to a later A login",
            h.router.transferPendingToRestoredActivity(
                owner, replacement, savedIdentity(oldTap), Intent(oldTap),
            ))
        assertFalse("Old queued event remained navigable after logout", host.isCurrent(oldEvent))
    }

    @Test fun blank_observed_user_retires_pending_A_without_a_mounted_host() {
        val h = Harness(physicallyStoredTicket = ticketA)
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(tap(firstId, routeA, userA), owner)

        // The SDK reports Authenticated but user/token parsing cannot produce
        // a ticket. MainActivity forwards the blank mapped ID, with no host.
        h.status = SdkStatus.Authenticated
        assertNull(h.source.currentTicket())
        assertNull(h.source.provisionalStoredTicketDuringInitializing())
        h.router.observeAuthenticatedSession(owner, "  ")
        h.authenticatedTicket = ticketA
        assertNull("Blank SignedIn retained a tap for a later valid A callback",
            h.router.takeStartupFor(owner, userA))
    }

    @Test fun blank_observed_user_retires_unfinished_A_after_host_unmounts() = runTest {
        val h = Harness(status = SdkStatus.Authenticated, authenticatedTicket = ticketA)
        val owner = DeepLinkRouter.LaunchOwner()
        val replacement = DeepLinkRouter.LaunchOwner()
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        val oldTap = tap(firstId, routeA, userA)
        h.router.beginActivity(owner)
        advanceUntilIdle()
        val registration = host.registerRouterSink(owner)
        registrations += registration
        h.router.dispatch(oldTap, owner)
        val unfinished = requireNotNull(host.nextEventOrNull())
        assertTrue(host.isCurrent(unfinished))

        // The old graph is gone before the Activity's blank SignedIn mapping.
        // Authenticated still has no parseable user/ticket at this moment.
        registration.close()
        host.viewModelScope.cancel()
        h.authenticatedTicket = null
        assertNull(h.source.currentTicket())
        h.router.observeAuthenticatedSession(owner, " ")
        h.authenticatedTicket = ticketA

        h.router.endActivityForRecreation(owner)
        assertFalse("Blank SignedIn left an unfinished A route transferable",
            h.router.transferPendingToRestoredActivity(
                owner, replacement, savedIdentity(oldTap), Intent(oldTap),
            ))
    }

    @Test fun delayed_blank_A_callback_cannot_erase_a_newer_authenticated_B_tap() {
        val h = Harness(physicallyStoredTicket = ticketB)
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(tap(nextId, routeB, userB), owner)

        // B has already become the exact SDK login when an older malformed
        // mapped callback arrives. Blank with a live B witness is not B's
        // missing-identity boundary.
        h.status = SdkStatus.Authenticated
        h.authenticatedTicket = ticketB
        h.router.observeAuthenticatedSession(owner, " ")
        assertEquals(routeB, h.router.takeStartupFor(owner, userB)?.route)
        assertNull(h.router.takeStartupFor(owner, userB))
    }

    @Test fun delayed_old_A_logout_does_not_erase_a_newer_exact_B_tap() {
        val h = Harness(status = SdkStatus.Authenticated, authenticatedTicket = ticketA)
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.status = SdkStatus.Initializing
        h.authenticatedTicket = null
        h.physicallyStoredTicket = ticketB
        h.router.dispatchStartup(tap(nextId, routeB, userB), owner)

        // The ticket source already moved to B before an old A logout arrives.
        // An exact B restoration witness protects B's newer local tap.
        h.router.retireStartupForTerminalSession(owner)
        h.status = SdkStatus.Authenticated
        h.authenticatedTicket = ticketB
        assertEquals(routeB, h.router.takeStartupFor(owner, userB)?.route)
        assertNull(h.router.takeStartupFor(owner, userB))
    }

    private fun tap(id: String, route: String, recipient: String): Intent = Intent()
        .setData(Uri.parse("equipseva-internal-notification://tap/$id"))
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)

    private fun savedIdentity(intent: Intent): String = Bundle().also {
        RestoredTaskIngress.record(it, intent)
    }.let { saved -> requireNotNull(saved.getString(saved.keySet().single())) }

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

    private suspend fun DeepLinkHost.nextEventOrNull(): DeepLinkHost.VerifiedEvent.OpenRoute? =
        withTimeoutOrNull(50) { events.first() as DeepLinkHost.VerifiedEvent.OpenRoute }
}
