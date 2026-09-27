package com.equipseva.app.navigation

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

/**
 * MainActivity can observe SDK auth while role or onboarding keeps the main graph unmounted.
 * These boundaries must retire stale taps without depending on a DeepLinkHost registration.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkActivityAuthBoundaryTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val loginA1 = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val loginA2 = LoginTicketSnapshot(userA, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    private val loginB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val routeOne = Routes.repairJobDetailRoute("RPR-00027")
    private val routeTwo = Routes.repairJobDetailRoute("RPR-00028")

    private inner class Tickets(
        var sdk: LoginTicketSnapshot? = null,
        var provisional: LoginTicketSnapshot? = null,
    ) {
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers { sdk }
            every { provisionalStoredTicketDuringInitializing() } answers { provisional }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun different_authenticated_account_retires_a_restoring_tap_before_any_host_mounts() {
        val tickets = Tickets(provisional = loginA1)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        tickets.router.dispatchStartup(push(routeOne, userA), owner)

        // A role/onboarding screen can keep DeepLinkHost absent while B becomes authenticated.
        tickets.provisional = null
        tickets.sdk = loginB
        tickets.router.observeAuthenticatedSession(owner, userB)

        // Even a later A login with the exact old ticket cannot reclaim that tap.
        tickets.sdk = loginA1
        assertNull(tickets.router.takeStartupFor(owner, userA))
    }

    @Test fun observed_B_with_no_current_ticket_retires_A_before_A_can_return() {
        val tickets = Tickets(provisional = loginA1)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        tickets.router.dispatchStartup(push(routeOne, userA), owner)

        // The mapped B callback is observed after the SDK has left A's
        // restoration state but before a parseable B ticket is available.
        tickets.provisional = null
        tickets.router.observeAuthenticatedSession(owner, userB)
        tickets.sdk = loginA1
        assertNull("A reclaimed a pre-B tap after the observed boundary",
            tickets.router.takeStartupFor(owner, userA))
    }

    @Test fun delayed_old_signed_in_callback_cannot_erase_a_newer_exact_restoring_ticket() {
        val tickets = Tickets(provisional = loginB)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        tickets.router.dispatchStartup(push(routeOne, userB), owner)

        tickets.router.observeAuthenticatedSession(owner, userA) // Delayed A callback.
        tickets.provisional = null
        tickets.sdk = loginB
        assertEquals(routeOne, tickets.router.takeStartupFor(owner, userB)?.route)
        assertNull(tickets.router.takeStartupFor(owner, userB))
    }

    @Test fun same_user_new_session_retires_A1_but_preserves_a_fresh_A2_tap() {
        val tickets = Tickets(provisional = loginA1)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        tickets.router.dispatchStartup(push(routeOne, userA), owner)

        tickets.provisional = null
        tickets.sdk = loginA2
        tickets.router.observeAuthenticatedSession(owner, userA)
        tickets.sdk = loginA1
        assertNull("Old A1 tap survived observed A2 authentication", tickets.router.takeStartupFor(owner, userA))

        tickets.sdk = null
        tickets.provisional = loginA2
        tickets.router.dispatchStartup(push(routeTwo, userA), owner)
        tickets.router.observeAuthenticatedSession(owner, userA) // Delayed callback while A2 restores.
        tickets.provisional = null
        tickets.sdk = loginA2
        assertEquals(routeTwo, tickets.router.takeStartupFor(owner, userA)?.route)
        assertNull(tickets.router.takeStartupFor(owner, userA))
    }

    @Test fun terminal_signed_out_without_any_ticket_retires_the_tap() {
        val tickets = Tickets(provisional = loginA1)
        val owner = DeepLinkRouter.LaunchOwner()
        tickets.router.beginActivity(owner)
        tickets.router.dispatchStartup(push(routeOne, userA), owner)

        tickets.provisional = null
        tickets.router.retireStartupForTerminalSession(owner)
        tickets.sdk = loginA1
        assertNull(tickets.router.takeStartupFor(owner, userA))
    }

    private fun push(route: String, recipient: String): Intent = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)
}
