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

    // Defensive — make sure the regex bounds hold against typo'd /
    // hostile inputs. Without these, a future tweak that loosens
    // JOB_ID_REGEX (e.g. drops `^...$` anchors) would silently route
    // garbage to RepairJobDetailScreen which then 404s against Supabase.
    @Test fun `malformed RPR ids return null`() {
        val host = "equipseva.com"
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-abc")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-1a")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "PRP-123")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "123")))
        // 9+ digits exceeds the {1,8} cap.
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-123456789")))
    }

    @Test fun `valid RPR id at length boundary routes`() {
        val host = "equipseva.com"
        // Boundary cases of {1,8}: exactly 1 and exactly 8 digits both match.
        assertEquals(
            Routes.repairJobDetailRoute("RPR-1"),
            DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-1")),
        )
        assertEquals(
            Routes.repairJobDetailRoute("RPR-12345678"),
            DeepLinkRouter.routeForParts("https", host, listOf("job", "RPR-12345678")),
        )
    }

    @Test fun `RPR regex is case insensitive`() {
        val host = "equipseva.com"
        assertEquals(
            Routes.repairJobDetailRoute("rpr-42"),
            DeepLinkRouter.routeForParts("https", host, listOf("job", "rpr-42")),
        )
    }

    @Test fun `malformed UUIDs on chat and engineer paths return null`() {
        val host = "equipseva.com"
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("chat", "not-a-uuid")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("engineer", "not-a-uuid")))
        // RPR id in a UUID slot — id-format guard means /chat/RPR-1 must NOT route.
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("chat", "RPR-1")))
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("engineer", "RPR-1")))
        // UUID with wrong dash positions / wrong group lengths.
        assertNull(DeepLinkRouter.routeForParts("https", host, listOf("chat", "1234-5678-90ab-cdef")))
        // Trailing garbage past the UUID end.
        assertNull(
            DeepLinkRouter.routeForParts(
                "https",
                host,
                listOf("chat", "$sampleUuid;hack"),
            ),
        )
    }

    @Test fun `UUID on job path returns null`() {
        // Inverse of above: a real UUID where an RPR id is expected
        // should not silently route. Catches a future refactor that
        // unifies the id regexes by accident.
        assertNull(
            DeepLinkRouter.routeForParts("https", "equipseva.com", listOf("job", sampleUuid)),
        )
    }
}
