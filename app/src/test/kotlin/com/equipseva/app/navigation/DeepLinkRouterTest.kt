package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeepLinkRouterTest {

    private val sampleUuid = "11111111-2222-3333-4444-555555555555"
    private val otherUuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    @Test fun `null scheme or wrong scheme returns null`() {
        assertNull(DeepLinkRouter.routeForParts(null, "equipseva.com", listOf("job", "RPR-1")))
        assertNull(DeepLinkRouter.routeForParts("http", "equipseva.com", listOf("job", "RPR-1")))
    }

    @Test fun `unknown host returns null`() {
        assertNull(DeepLinkRouter.routeForParts("https", "evil.com", listOf("job", "RPR-1")))
        assertNull(DeepLinkRouter.routeForParts("https", null, listOf("job", "RPR-1")))
    }

    @Test fun `both equipseva hosts are accepted`() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-1"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "RPR-1")),
        )
        assertEquals(
            Routes.repairJobDetailRoute("RPR-1"),
            DeepLinkRouter.routeForParts("https", "www.equipseva.com", listOf("job", "RPR-1")),
        )
    }

    @Test fun `job, chat, engineer paths route by id`() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-1"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "RPR-1")),
        )
        assertEquals(
            Routes.chatRoute(sampleUuid),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("chat", sampleUuid)),
        )
        assertEquals(
            Routes.engineerPublicProfileRoute(otherUuid),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("engineer", otherUuid)),
        )
    }

    @Test fun `engineers and notifications root paths resolve`() {
        assertEquals(
            Routes.ENGINEER_DIRECTORY,
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("engineers")),
        )
        assertEquals(
            Routes.NOTIFICATIONS,
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("notifications")),
        )
    }

    @Test fun `empty id, wrong-depth, or unknown path returns null`() {
        assertNull(DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "")))
        assertNull(DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job")))
        assertNull(DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "a", "b")))
        assertNull(DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("foo")))
        assertNull(DeepLinkRouter.routeForParts("https", "equipseva.com", emptyList()))
    }
}
