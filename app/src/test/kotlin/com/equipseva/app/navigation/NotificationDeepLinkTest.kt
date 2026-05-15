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
    fun `unknown kind returns null so caller falls back to inbox`() {
        val route = NotificationDeepLink.routeFor(
            kind = "totally_made_up_kind",
            data = mapOf("repair_job_id" to sampleUuid),
        )
        assertNull(route)
    }

    @Test
    fun `null kind returns null`() {
        assertNull(NotificationDeepLink.routeFor(kind = null, data = mapOf("repair_job_id" to sampleUuid)))
    }

    @Test
    fun `blank kind returns null`() {
        assertNull(NotificationDeepLink.routeFor(kind = "   ", data = mapOf("repair_job_id" to sampleUuid)))
    }

    @Test
    fun `missing id field returns null`() {
        // chat_message_new without conversation_id should not pull from a
        // sibling field — we want the call site to fall back to the inbox.
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
                data = mapOf("repair_job_id" to sampleUuid),
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
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "not-a-uuid"),
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
            kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
            data = mapOf("repair_job_id" to upper),
        )
        assertEquals(Routes.repairJobDetailRoute(upper), route)
    }

    @Test
    fun `kyc_status_changed resolves to KYC route without payload id`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_KYC_STATUS_CHANGED,
            data = emptyMap(),
        )
        assertEquals(Routes.KYC, route)
    }

    @Test
    fun `repair_job_id accepts RPR-NNNNN job_number per PR 651`() {
        // Server triggers may emit the public job_number rather than the
        // UUID id. PR #651 made fetchById accept both; the deep-link
        // resolver should too so the push doesn't fall through to inbox.
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
            data = mapOf("repair_job_id" to "RPR-00027"),
        )
        assertEquals(Routes.repairJobDetailRoute("RPR-00027"), route)
    }

    @Test
    fun `repair_job_id RPR code is case-insensitive`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_ESCROW_DISPUTE_OPENED,
            data = mapOf("repair_job_id" to "rpr-00001"),
        )
        assertEquals(Routes.repairJobDetailRoute("rpr-00001"), route)
    }

    @Test
    fun `malformed repair_job_id still falls through to inbox`() {
        // Anything that isn't UUID OR RPR-NNNNN should reject so a
        // junk payload from a future migration can't push the user to
        // a 404 route.
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "not-a-job-id"),
            ),
        )
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "RPR-"),
            ),
        )
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "RPR-123456789"),
            ),
        )
    }

    @Test
    fun `engineer_id and amc_contract_id remain UUID-only`() {
        // Only repair_jobs has a public RPR-NNNNN code; the engineer
        // and AMC contract tables don't, so those id slots stay
        // UUID-only.
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_LOYAL_PAIR_NUDGE,
                data = mapOf("engineer_id" to "RPR-00027"),
            ),
        )
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_SLA_BREACH,
                data = mapOf("amc_contract_id" to "RPR-00027"),
            ),
        )
    }
}
