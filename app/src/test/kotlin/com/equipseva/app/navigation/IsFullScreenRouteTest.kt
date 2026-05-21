package com.equipseva.app.navigation

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the route → bottom-bar visibility decision. The list of
 * "full-screen" routes is exposed at module scope so the predicate is
 * easy to evolve, but the match semantics (prefix, null tolerance,
 * inheritance for sub-routes) need pinning so a refactor doesn't
 * silently switch to exact-match (which would let `repair/detail/<id>`
 * show the bottom bar again).
 */
class IsFullScreenRouteTest {

    @Test fun `null route yields false (loading state shows bottom bar)`() {
        // During cold composition the currentRoute is null briefly —
        // the bottom bar must render so users have something the
        // moment a destination resolves.
        assertFalse(isFullScreenRoute(null))
    }

    @Test fun `top-level bottom-nav routes do NOT hide the bottom bar`() {
        // Pin so a refactor doesn't accidentally add HOME to the
        // full-screen list (would tear the bottom bar off the Home
        // tab entirely).
        assertFalse(isFullScreenRoute(Routes.HOME))
        assertFalse(isFullScreenRoute(Routes.PROFILE))
        assertFalse(isFullScreenRoute(Routes.EARNINGS))
        assertFalse(isFullScreenRoute(Routes.HOSPITAL_ACTIVE_JOBS))
        // ENGINEER_JOBS_HUB is intentionally excluded — it IS a
        // bottom-nav tab, not a full-screen destination.
        assertFalse(isFullScreenRoute(Routes.ENGINEER_JOBS_HUB))
    }

    @Test fun `repair-detail sub-route inherits the parent's full-screen flag`() {
        // Critical: `repair/detail` is in the prefix list, so
        // `repair/detail/<job-uuid>` (the actual route at runtime)
        // must also be full-screen. Pin the prefix-match semantics.
        assertTrue(
            isFullScreenRoute(Routes.repairJobDetailRoute("11111111-2222-3333-4444-555555555555")),
        )
    }

    @Test fun `chat detail sub-route is full-screen`() {
        assertTrue(
            isFullScreenRoute(Routes.chatRoute("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")),
        )
    }

    @Test fun `engineer public profile sub-route is full-screen`() {
        assertTrue(isFullScreenRoute(Routes.engineerPublicProfileRoute("eng-1")))
    }

    @Test fun `KYC and other auth-flow routes are full-screen`() {
        assertTrue(isFullScreenRoute(Routes.KYC))
        assertTrue(isFullScreenRoute(Routes.ADD_PHONE))
        assertTrue(isFullScreenRoute(Routes.CHANGE_PASSWORD))
        assertTrue(isFullScreenRoute(Routes.CHANGE_EMAIL))
    }

    @Test fun `founder routes are full-screen`() {
        assertTrue(isFullScreenRoute(Routes.FOUNDER_DASHBOARD))
        assertTrue(isFullScreenRoute(Routes.FOUNDER_KYC_QUEUE))
        assertTrue(isFullScreenRoute(Routes.FOUNDER_REPORTS_QUEUE))
        assertTrue(isFullScreenRoute(Routes.FOUNDER_USERS))
    }

    @Test fun `notifications and notification-settings are full-screen`() {
        assertTrue(isFullScreenRoute(Routes.NOTIFICATIONS))
        assertTrue(isFullScreenRoute(Routes.NOTIFICATION_SETTINGS))
    }

    @Test fun `directory routes are full-screen`() {
        assertTrue(isFullScreenRoute(Routes.ENGINEER_DIRECTORY))
    }

    @Test fun `unknown route is NOT full-screen (default to bottom-bar visible)`() {
        // Forward-compat: a route added without being added to the
        // full-screen list defaults to bottom-bar visible. Caller
        // can opt-in by adding the prefix to fullScreenRoutePrefixes.
        assertFalse(isFullScreenRoute("future/unknown/route"))
    }

    @Test fun `routes that start with a known prefix as substring don't accidentally match`() {
        // Defensive: startsWith is the match semantic, not contains.
        // A route like "other/repair/detail" must NOT inherit the
        // full-screen flag.
        assertFalse(isFullScreenRoute("other/repair/detail/abc"))
    }
}
