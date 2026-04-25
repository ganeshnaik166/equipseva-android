package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pure unit tests — the resolver has no Android dependencies, so we can
 * exercise every branch from regular JUnit without Robolectric.
 */
class NotificationDeepLinkTest {

    private val sampleUuid = "11111111-2222-3333-4444-555555555555"

    @Test
    fun `chat_message_new resolves to chat route with conversation_id`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
            data = mapOf("conversation_id" to sampleUuid),
        )
        assertEquals(Routes.chatRoute(sampleUuid), route)
    }

    @Test
    fun `repair_bid_new resolves to repair job detail with repair_job_id`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
            data = mapOf("repair_job_id" to sampleUuid),
        )
        assertEquals(Routes.repairJobDetailRoute(sampleUuid), route)
    }

    @Test
    fun `order_shipped resolves to order detail with order_id`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_ORDER_SHIPPED,
            data = mapOf("order_id" to sampleUuid),
        )
        assertEquals(Routes.orderDetailRoute(sampleUuid), route)
    }

    @Test
    fun `rfq_bid_accepted resolves to hospital RFQ detail with rfq_id`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RFQ_BID_ACCEPTED,
            data = mapOf("rfq_id" to sampleUuid),
        )
        assertEquals(Routes.hospitalRfqDetailRoute(sampleUuid), route)
    }

    @Test
    fun `unknown kind returns null so caller falls back to inbox`() {
        val route = NotificationDeepLink.routeFor(
            kind = "totally_made_up_kind",
            data = mapOf("order_id" to sampleUuid),
        )
        assertNull(route)
    }

    @Test
    fun `null kind returns null`() {
        assertNull(NotificationDeepLink.routeFor(kind = null, data = mapOf("order_id" to sampleUuid)))
    }

    @Test
    fun `blank kind returns null`() {
        assertNull(NotificationDeepLink.routeFor(kind = "   ", data = mapOf("order_id" to sampleUuid)))
    }

    @Test
    fun `missing id field returns null`() {
        // chat_message_new without conversation_id should not pull from a
        // sibling field — we want the call site to fall back to the inbox.
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
                data = mapOf("order_id" to sampleUuid),
            ),
        )
    }

    @Test
    fun `non-uuid id is rejected`() {
        // FCM payload values are strings; refuse anything that isn't a
        // canonical UUID so a malformed server payload can't push the
        // user to a junk route.
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ORDER_SHIPPED,
                data = mapOf("order_id" to "not-a-uuid"),
            ),
        )
    }

    @Test
    fun `empty data map returns null for known kind`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = emptyMap(),
            ),
        )
    }

    @Test
    fun `uppercase uuid is accepted`() {
        // Postgres returns UUIDs lowercase by default but the resolver
        // shouldn't be picky about case.
        val upper = sampleUuid.uppercase()
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_ORDER_SHIPPED,
            data = mapOf("order_id" to upper),
        )
        assertEquals(Routes.orderDetailRoute(upper), route)
    }
}
