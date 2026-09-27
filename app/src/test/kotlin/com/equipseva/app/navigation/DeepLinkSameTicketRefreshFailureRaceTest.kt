package com.equipseva.app.navigation

import android.app.Application
import android.content.Intent
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** A mapped terminal callback can run after the SDK has already recovered its same ticket. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkSameTicketRefreshFailureRaceTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val oldRoute = Routes.repairJobDetailRoute("RPR-00027")
    private val freshRoute = Routes.repairJobDetailRoute("RPR-00028")

    private enum class SdkStatus { Initializing, Authenticated, RefreshFailure }

    private inner class Harness {
        var status = SdkStatus.Authenticated
        var sdkTicket = ticketA
        var storedTicket = ticketA
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers {
                sdkTicket.takeIf { status == SdkStatus.Authenticated }
            }
            every { provisionalStoredTicketDuringInitializing() } answers {
                storedTicket.takeIf { status == SdkStatus.Initializing }
            }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun late_RefreshFailure_callback_retires_queued_A_after_same_ticket_recovers() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.observeAuthenticatedSession(owner, userA) // MainActivity observed A before tap.
        h.router.dispatchStartup(tap(oldRoute, userA), owner) // No main host mounted.

        h.status = SdkStatus.RefreshFailure
        assertNull(h.source.currentTicket())
        assertNull(h.source.provisionalStoredTicketDuringInitializing())
        // The SDK publishes Authenticated(A) before the already-mapped SignedOut
        // reaches MainActivity. It is the same login ticket, not a new login.
        h.status = SdkStatus.Authenticated
        h.router.retireStartupForTerminalSession(owner)

        assertNull("The tap from before RefreshFailure remained claimable",
            h.router.takeStartupFor(owner, userA))
        h.router.dispatchStartup(tap(freshRoute, userA), owner)
        assertEquals(freshRoute, h.router.takeStartupFor(owner, userA)?.route)
        assertNull("A fresh tap navigated more than once", h.router.takeStartupFor(owner, userA))
    }

    @Test fun late_A_terminal_callback_keeps_new_B_ticket_tap() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.observeAuthenticatedSession(owner, userA)
        h.status = SdkStatus.RefreshFailure
        h.sdkTicket = ticketB
        h.status = SdkStatus.Authenticated
        h.router.dispatchStartup(tap(freshRoute, userB), owner)

        h.router.retireStartupForTerminalSession(owner)

        assertEquals("A's delayed callback erased B's newer exact tap",
            freshRoute, h.router.takeStartupFor(owner, userB)?.route)
        assertNull(h.router.takeStartupFor(owner, userB))
    }

    @Test fun late_RefreshFailure_callback_retires_provisional_A_after_same_ticket_recovers() {
        val h = Harness()
        h.status = SdkStatus.Initializing
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(tap(oldRoute, userA), owner)

        h.status = SdkStatus.RefreshFailure
        assertNull(h.source.currentTicket())
        assertNull(h.source.provisionalStoredTicketDuringInitializing())
        h.status = SdkStatus.Authenticated
        h.router.retireStartupForTerminalSession(owner)

        assertNull("A provisional tap crossed a failed restoration",
            h.router.takeStartupFor(owner, userA))
        h.router.dispatchStartup(tap(freshRoute, userA), owner)
        assertEquals(freshRoute, h.router.takeStartupFor(owner, userA)?.route)
        assertNull(h.router.takeStartupFor(owner, userA))
    }

    @Test fun late_RefreshFailure_retires_A_when_SDK_ticket_preceded_mapped_SignedIn() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        // The SDK became Authenticated just before ingress, but the Activity
        // collector has not yet received its mapped SignedIn callback.
        h.router.dispatchStartup(tap(oldRoute, userA), owner)

        h.status = SdkStatus.RefreshFailure
        assertNull(h.source.currentTicket())
        h.status = SdkStatus.Authenticated
        h.router.retireStartupForTerminalSession(owner)

        assertNull("An unobserved exact SDK ticket kept a pre-failure tap",
            h.router.takeStartupFor(owner, userA))
        h.router.dispatchStartup(tap(freshRoute, userA), owner)
        assertEquals(freshRoute, h.router.takeStartupFor(owner, userA)?.route)
        assertNull(h.router.takeStartupFor(owner, userA))
    }

    @Test fun late_A_terminal_callback_keeps_B_tap_restored_before_callback() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.observeAuthenticatedSession(owner, userA)
        h.status = SdkStatus.Initializing
        h.storedTicket = ticketB
        h.router.dispatchStartup(tap(freshRoute, userB), owner)

        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketB
        h.router.retireStartupForTerminalSession(owner)

        assertEquals("A's late callback erased B's restored exact tap",
            freshRoute, h.router.takeStartupFor(owner, userB)?.route)
        assertNull(h.router.takeStartupFor(owner, userB))
    }

    private fun tap(route: String, recipient: String) = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)
}
