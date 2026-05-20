package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the pure intent-extra → Event decision inside DeepLinkRouter.
 * The router is the single seam between Android's intent system and
 * the Compose nav graph — a regression here either drops legitimate
 * push-notification deep links on the floor (silent dead-end) or
 * forwards garbage routes that the nav graph then explodes on.
 *
 * The Intent itself isn't constructable in a pure JUnit test, so the
 * router's dispatch() defers to the internal helper
 * [eventForRouteExtra] which works on the raw extra string. That's
 * what we test here.
 */
class DeepLinkRouterTest {

    @Test fun `null extra produces no event`() {
        // A launch intent with no ROUTE extra (e.g. user opened the
        // app from the launcher) has to be a no-op. If this drifts
        // we end up emitting OpenRoute("null") and crashing the nav
        // graph on every cold start.
        assertNull(eventForRouteExtra(null))
    }

    @Test fun `blank extra produces no event`() {
        assertNull(eventForRouteExtra(""))
    }

    @Test fun `whitespace-only extra produces no event`() {
        // Push payload defensiveness — if FCM ever sends a route of
        // "   " we'd rather silently swallow it than navigate to a
        // route that doesn't exist.
        assertNull(eventForRouteExtra("   "))
        assertNull(eventForRouteExtra("\n\t"))
    }

    @Test fun `non-blank extra produces OpenRoute verbatim`() {
        val event = eventForRouteExtra("jobDetail/abc-123")
        assertEquals(DeepLinkRouter.Event.OpenRoute("jobDetail/abc-123"), event)
    }

    @Test fun `route is forwarded without trimming`() {
        // Routes with leading/trailing whitespace shouldn't really
        // happen — FCM mapping in NotificationDeepLink emits clean
        // strings — but if one slips through, we forward as-is.
        // The nav graph is the source of truth for validity, not
        // the router. Pinning this so a future "be helpful and
        // trim" change doesn't silently mask upstream bugs.
        val event = eventForRouteExtra("  jobs  ")
        assertEquals(DeepLinkRouter.Event.OpenRoute("  jobs  "), event)
    }

    @Test fun `route with query parameters preserved verbatim`() {
        val raw = "engineer/profile?focus=kyc"
        val event = eventForRouteExtra(raw)
        assertEquals(DeepLinkRouter.Event.OpenRoute(raw), event)
    }

    @Test fun `EXTRA_ROUTE key contract is stable`() {
        // The FCM messaging service stamps this exact key on
        // launch intents. If it drifts here, push notifications
        // silently stop deep-linking. The constant is a public
        // contract between two files — pin it.
        assertEquals(
            "com.equipseva.app.deeplink.ROUTE",
            DeepLinkRouter.EXTRA_ROUTE,
        )
    }
}
