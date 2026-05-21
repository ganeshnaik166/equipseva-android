package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the notification deep-link → route resolution. Push payloads carry
 * one of three shapes:
 *
 *   1) `app://<kind>/<uuid>` or `equipseva://<kind>/<uuid>` for entity links;
 *   2) `app://<top>` / `equipseva://<top>` for top-level destinations;
 *   3) a bare route string (legacy server payloads that already speak
 *      our NavGraph language).
 *
 * The UUID gate is intentional — without it a typo'd job id "abc"
 * would still navigate, then crash on backstack pop. Any regression
 * that loosened the UUID match would surface as routing-to-junk on
 * release. Keep the gate strict here.
 */
class ResolveNotificationDeepLinkTest {

    private val sampleJobId = "11111111-2222-3333-4444-555555555555"
    private val sampleConvId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    @Test fun `blank link yields null`() {
        assertNull(resolveNotificationDeepLink(""))
        assertNull(resolveNotificationDeepLink("   "))
    }

    @Test fun `app scheme repair UUID resolves to repair detail route`() {
        assertEquals(
            Routes.repairJobDetailRoute(sampleJobId),
            resolveNotificationDeepLink("app://repair/$sampleJobId"),
        )
    }

    @Test fun `equipseva scheme repair UUID resolves equally`() {
        assertEquals(
            Routes.repairJobDetailRoute(sampleJobId),
            resolveNotificationDeepLink("equipseva://repair/$sampleJobId"),
        )
    }

    @Test fun `app scheme chat UUID resolves to chat-detail route`() {
        assertEquals(
            Routes.chatRoute(sampleConvId),
            resolveNotificationDeepLink("app://chat/$sampleConvId"),
        )
    }

    @Test fun `non-UUID entity id is rejected`() {
        // Strict gate — a typo or missing dash would silently navigate
        // and crash on backstack pop. Better to surface the snackbar.
        assertNull(resolveNotificationDeepLink("app://repair/not-a-uuid"))
        assertNull(resolveNotificationDeepLink("app://chat/12345"))
    }

    @Test fun `top-level app scheme links resolve to bare routes`() {
        assertEquals("home", resolveNotificationDeepLink("app://home"))
        assertEquals("repair", resolveNotificationDeepLink("app://repair"))
        assertEquals("profile", resolveNotificationDeepLink("app://profile"))
    }

    @Test fun `top-level app scheme chat link resolves to CONVERSATIONS`() {
        // Special-case: a top-level "chat" link should open the inbox,
        // not the single-conversation detail.
        assertEquals(
            Routes.CONVERSATIONS,
            resolveNotificationDeepLink("app://chat"),
        )
    }

    @Test fun `bare top-level route strings pass through`() {
        assertEquals(Routes.HOME, resolveNotificationDeepLink(Routes.HOME))
        assertEquals(Routes.REPAIR, resolveNotificationDeepLink(Routes.REPAIR))
        assertEquals(Routes.PROFILE, resolveNotificationDeepLink(Routes.PROFILE))
        assertEquals(Routes.CONVERSATIONS, resolveNotificationDeepLink(Routes.CONVERSATIONS))
    }

    @Test fun `unknown scheme yields null instead of navigating to junk`() {
        assertNull(resolveNotificationDeepLink("https://equipseva.com/foo"))
        assertNull(resolveNotificationDeepLink("file:///etc/passwd"))
    }

    @Test fun `unknown bare route yields null`() {
        assertNull(resolveNotificationDeepLink("future_screen"))
        assertNull(resolveNotificationDeepLink("settings"))
    }

    @Test fun `extra path segments after the entity id are tolerated`() {
        // server-side may append a trailing query path (e.g. for
        // analytics tagging); only the first two segments matter.
        assertEquals(
            Routes.repairJobDetailRoute(sampleJobId),
            resolveNotificationDeepLink("app://repair/$sampleJobId/extra"),
        )
    }

    @Test fun `whitespace around the link is trimmed before parsing`() {
        assertEquals(
            Routes.repairJobDetailRoute(sampleJobId),
            resolveNotificationDeepLink("   app://repair/$sampleJobId\n"),
        )
    }
}
