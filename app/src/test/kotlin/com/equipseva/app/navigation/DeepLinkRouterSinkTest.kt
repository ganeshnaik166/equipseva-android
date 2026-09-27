package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** An ingress without both a current login and a live host must never be buffered. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkRouterSinkTest {
    private val ticketA = LoginTicketSnapshot(
        userId = "a1111111-1111-4111-8111-111111111111",
        sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    )
    private val ticketB = LoginTicketSnapshot(
        userId = "22222222-2222-4222-8222-222222222222",
        sessionId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    )

    @Test fun no_sink_drops_route_instead_of_replaying_to_later_host() {
        val tickets = ticketSource(ticketA)
        val router = DeepLinkRouter(tickets)
        router.dispatch(routeIntent(Routes.HOME))

        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }
        assertTrue(received.isEmpty())

        router.dispatch(routeIntent(Routes.PROFILE))
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.PROFILE, ticketA)), received)
    }

    @Test fun missing_ticket_drops_route_and_fresh_login_can_still_receive_new_route() {
        val tickets = ticketSource(null)
        val router = DeepLinkRouter(tickets)
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.HOME))
        assertTrue(received.isEmpty())

        every { tickets.currentTicket() } returns ticketB
        assertTrue(received.isEmpty())
        router.dispatch(routeIntent(Routes.PROFILE, ticketB.userId))
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.PROFILE, ticketB)), received)
    }

    @Test fun valid_route_is_delivered_synchronously_once_with_its_ingress_ticket() {
        val tickets = ticketSource(ticketA)
        val router = DeepLinkRouter(tickets)
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.NOTIFICATIONS))

        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.NOTIFICATIONS, ticketA)), received)
        verify(exactly = 1) { tickets.currentTicket() }
    }

    @Test fun replacement_sink_owns_close_and_old_close_cannot_remove_new_sink() {
        val tickets = ticketSource(ticketA)
        val router = DeepLinkRouter(tickets)
        val old = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        val current = mutableListOf<DeepLinkRouter.Event.OpenRoute>()

        val oldRegistration = router.registerSink { old += it }
        val currentRegistration = router.registerSink { current += it }
        oldRegistration.close()
        router.dispatch(routeIntent(Routes.HOME))

        assertTrue(old.isEmpty())
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.HOME, ticketA)), current)
        currentRegistration.close()
        router.dispatch(routeIntent(Routes.PROFILE))
        assertEquals(1, current.size)
    }

    @Test fun denied_extra_never_reads_ticket_or_reaches_sink() {
        val tickets = ticketSource(ticketA)
        val router = DeepLinkRouter(tickets)
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.FOUNDER_DASHBOARD))

        assertTrue(received.isEmpty())
        verify(exactly = 0) { tickets.currentTicket() }
    }

    @Test fun valid_app_link_wins_over_denied_extra_and_keeps_current_ticket() {
        val router = DeepLinkRouter(ticketSource(ticketA))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.FOUNDER_DASHBOARD).apply {
            data = Uri.parse("https://equipseva.com/job/RPR-00027")
        })

        assertEquals(
            listOf(DeepLinkRouter.Event.OpenRoute(Routes.repairJobDetailRoute("RPR-00027"), ticketA)),
            received,
        )
    }

    @Test fun allowed_extra_keeps_priority_over_app_link() {
        val router = DeepLinkRouter(ticketSource(ticketA))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.PROFILE).apply {
            data = Uri.parse("https://equipseva.com/notifications")
        })

        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.PROFILE, ticketA)), received)
    }

    @Test fun caller_supplied_identity_extra_cannot_replace_the_SDK_ticket() {
        val router = DeepLinkRouter(ticketSource(ticketA))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.HOME).apply {
            putExtra("user_id", ticketB.userId)
            putExtra("session_id", ticketB.sessionId)
        })

        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.HOME, ticketA)), received)
    }

    @Test fun A_targeted_tray_tap_under_B_does_not_adopt_B_ticket() {
        val router = DeepLinkRouter(ticketSource(ticketB))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.HOME, ticketA.userId))

        assertTrue("A-targeted push navigated under B", received.isEmpty())
        router.dispatch(routeIntent(Routes.HOME, ticketB.userId))
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(Routes.HOME, ticketB)), received)
    }

    @Test fun notification_route_without_a_matching_canonical_recipient_is_dropped() {
        assertTrue("Fixture must contain a letter to test uppercase mismatch", ticketA.userId.uppercase() != ticketA.userId)
        val router = DeepLinkRouter(ticketSource(ticketA))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        listOf(null, "", " ${ticketA.userId}", ticketA.userId.uppercase(), "not-a-uuid",
            "00000000-0000-0000-0000-000000000000").forEach { recipient ->
            router.dispatch(routeIntent(Routes.HOME, recipient))
        }

        assertTrue("Missing or malformed recipient reached the host", received.isEmpty())
    }

    @Test fun stale_recipient_drops_inbox_fallback_but_valid_app_link_remains_independent() {
        val router = DeepLinkRouter(ticketSource(ticketB))
        val received = mutableListOf<DeepLinkRouter.Event.OpenRoute>()
        router.registerSink { received += it }

        router.dispatch(routeIntent(Routes.FOUNDER_CASH_SUSPENDED, ticketA.userId))
        assertTrue("Stale notification reached the inbox under B", received.isEmpty())

        router.dispatch(routeIntent(Routes.HOME, ticketA.userId).apply {
            data = Uri.parse("https://equipseva.com/notifications")
        })
        assertEquals(
            listOf(DeepLinkRouter.Event.OpenRoute(Routes.NOTIFICATIONS, ticketB)),
            received,
        )
    }

    private fun ticketSource(ticket: LoginTicketSnapshot?): LoginTicketSource = mockk {
        every { currentTicket() } returns ticket
    }

    private fun routeIntent(route: String, recipient: String? = ticketA.userId): Intent =
        Intent().putExtra(DeepLinkRouter.EXTRA_ROUTE, route).apply {
            if (recipient != null) putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)
        }
}
