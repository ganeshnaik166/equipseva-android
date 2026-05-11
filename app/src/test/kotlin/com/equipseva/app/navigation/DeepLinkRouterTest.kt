package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeepLinkRouterTest {

    @Test fun `null scheme or wrong scheme returns null`() {
        assertNull(DeepLinkRouter.routeForParts(null, "equipseva.com", listOf("job", "abc")))
        assertNull(DeepLinkRouter.routeForParts("http", "equipseva.com", listOf("job", "abc")))
    }

    @Test fun `unknown host returns null`() {
        assertNull(DeepLinkRouter.routeForParts("https", "evil.com", listOf("job", "abc")))
        assertNull(DeepLinkRouter.routeForParts("https", null, listOf("job", "abc")))
    }

    @Test fun `both equipseva hosts are accepted`() {
        assertEquals(
            Routes.repairJobDetailRoute("abc"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "abc")),
        )
        assertEquals(
            Routes.repairJobDetailRoute("abc"),
            DeepLinkRouter.routeForParts("https", "www.equipseva.com", listOf("job", "abc")),
        )
    }

    @Test fun `job, chat, engineer paths route by id`() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-1"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", "RPR-1")),
        )
        assertEquals(
            Routes.chatRoute("conv-1"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("chat", "conv-1")),
        )
        assertEquals(
            Routes.engineerPublicProfileRoute("eng-1"),
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("engineer", "eng-1")),
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
