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

/** Router acknowledgement races use synthetic tickets and Intents; no auth network or device state. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkAcknowledgedIngressTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val routeOne = Routes.repairJobDetailRoute("RPR-00027")
    private val routeTwo = Routes.repairJobDetailRoute("RPR-00028")

    private inner class Tickets {
        var sdkTicket: LoginTicketSnapshot? = ticketA
        var provisionalTicket: LoginTicketSnapshot? = null
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers { sdkTicket }
            every { provisionalStoredTicketDuringInitializing() } answers { provisionalTicket }
        }
        val router = DeepLinkRouter(source)

        fun restoring(ticket: LoginTicketSnapshot = ticketA) {
            sdkTicket = null
            provisionalTicket = ticket
        }

        fun authenticated(ticket: LoginTicketSnapshot = ticketA) {
            provisionalTicket = null
            sdkTicket = ticket
        }
    }

    @Test fun rejected_mounted_sink_holds_exact_ticket_until_restored_and_claims_once() {
        val h = Tickets()
        val owner = DeepLinkRouter.LaunchOwner()
        val other = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.beginActivity(other)
        val registration = h.router.registerAcknowledgingSink(owner) {
            // SDK goes to Initializing after the router's authenticated read.
            h.restoring()
            false
        }
        try {
            h.router.dispatch(push(routeOne), owner)
            assertNull("Another Activity must not claim this handoff", h.router.takeStartupFor(other, userA))
            assertNull("The stored witness cannot authorize navigation", h.router.takeStartupFor(owner, userA))
            h.authenticated()
            assertEquals(routeOne, h.router.takeStartupFor(owner, userA)?.route)
            assertNull("An acknowledged handoff must be one-shot", h.router.takeStartupFor(owner, userA))
        } finally {
            registration.close()
            h.router.endActivity(owner)
            h.router.endActivity(other)
        }
    }

    @Test fun same_owner_reentrant_newer_tap_wins_over_older_rejected_callback() {
        val h = Tickets()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val registration = h.router.registerAcknowledgingSink(owner) { event ->
            if (event.route == routeOne) {
                // A newer ingress finishes while the first callback remains on the stack.
                h.router.dispatch(push(routeTwo), owner)
            } else {
                h.restoring()
            }
            false
        }
        try {
            h.router.dispatch(push(routeOne), owner)
            h.authenticated()
            assertEquals("The older rejection overwrote the later tap", routeTwo,
                h.router.takeStartupFor(owner, userA)?.route)
            assertNull(h.router.takeStartupFor(owner, userA))
        } finally {
            registration.close()
            h.router.endActivity(owner)
        }
    }

    @Test fun new_Activity_handoff_wins_over_old_Activity_rejected_callback() {
        val h = Tickets()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(oldOwner)
        val registration = h.router.registerAcknowledgingSink(oldOwner) {
            // A second Activity starts while the old sink callback is in flight.
            h.router.beginActivity(newOwner)
            h.restoring()
            h.router.dispatchStartup(push(routeTwo), newOwner)
            false
        }
        try {
            h.router.dispatch(push(routeOne), oldOwner)
            h.authenticated()
            assertEquals("Old Activity rejection replaced the newer Activity's tap", routeTwo,
                h.router.takeStartupFor(newOwner, userA)?.route)
            assertNull(h.router.takeStartupFor(oldOwner, userA))
            assertNull(h.router.takeStartupFor(newOwner, userA))
        } finally {
            registration.close()
            h.router.endActivity(oldOwner)
            h.router.endActivity(newOwner)
        }
    }

    @Test fun warm_onNewIntent_without_sink_holds_only_an_exact_provisional_ticket() {
        val h = Tickets()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.restoring()

        h.router.dispatch(push(routeOne), owner)
        assertNull(h.router.takeStartupFor(owner, userA))
        h.authenticated()
        assertEquals(routeOne, h.router.takeStartupFor(owner, userA)?.route)
        assertNull(h.router.takeStartupFor(owner, userA))
    }

    @Test fun other_account_or_missing_witness_never_buffers_the_tap_for_A() {
        val wrongAccount = Tickets()
        val wrongOwner = DeepLinkRouter.LaunchOwner()
        wrongAccount.router.beginActivity(wrongOwner)
        wrongAccount.restoring(ticketB)
        wrongAccount.router.dispatch(push(routeOne), wrongOwner)
        wrongAccount.authenticated(ticketA)
        assertNull("B's provisional identity admitted A's push", wrongAccount.router.takeStartupFor(wrongOwner, userA))

        val missing = Tickets()
        val missingOwner = DeepLinkRouter.LaunchOwner()
        missing.router.beginActivity(missingOwner)
        missing.restoring()
        missing.provisionalTicket = null
        missing.router.dispatch(push(routeOne), missingOwner)
        missing.authenticated(ticketA)
        assertNull("An unowned tap was saved for a future A login", missing.router.takeStartupFor(missingOwner, userA))
    }

    @Test fun successful_ack_emits_once_without_leaving_a_handoff() {
        val h = Tickets()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val accepted = mutableListOf<String>()
        val registration = h.router.registerAcknowledgingSink(owner) { event ->
            accepted += event.route
            true
        }
        try {
            h.router.dispatch(push(routeOne), owner)
            assertEquals(listOf(routeOne), accepted)
            assertNull("A successful ack must not leave a second delivery", h.router.takeStartupFor(owner, userA))
        } finally {
            registration.close()
            h.router.endActivity(owner)
        }
    }

    private fun push(route: String): Intent = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, userA)
}
