package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Current pure-mapper contract, using synthetic identifiers. Returned routes
 * are navigation candidates, not proof of authenticated access or row ownership.
 * Null is the mapper result; caller inbox fallback is not exercised here.
 * A3 authorization/replay targets belong to the coordinator's host/router tests.
 * No assertion here endorses privileged routes or changes admission policy.
 */
class NotificationDeepLinkEdgeCasesTest {

    @Test
    fun `chat message maps to route with valid uuid`() {
        assertEquals(
            Routes.chatRoute("11111111-2222-3333-4444-555555555555"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
                data = mapOf("conversation_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )
    }

    @Test
    fun `repair bid resolves with uuid and RPR job code`() {
        assertEquals(
            Routes.repairJobDetailRoute("11111111-2222-3333-4444-555555555555"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )

        assertEquals(
            Routes.repairJobDetailRoute("RPR-12345678"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "RPR-12345678"),
            ),
        )
    }

    @Test
    fun `rate and cost-revision kinds still route through job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute("d4a1b2c3-1111-2222-3333-444444444444"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_RATE_ENGINEER,
                data = mapOf("repair_job_id" to "d4a1b2c3-1111-2222-3333-444444444444"),
            ),
        )

        assertEquals(
            Routes.repairJobDetailRoute("d4a1b2c3-1111-2222-3333-444444444444"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_COST_REVISION_PROPOSED,
                data = mapOf("repair_job_id" to "d4a1b2c3-1111-2222-3333-444444444444"),
            ),
        )
    }

    @Test
    fun `amc identifiers select their documented destination types`() {
        assertEquals(
            Routes.amcContractDetailRoute("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_SLA_BREACH,
                data = mapOf("amc_contract_id" to "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"),
            ),
        )

        assertEquals(
            Routes.engineerPublicProfileRoute("bbbbbbbb-cccc-dddd-eeee-ffffffffffff"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_LOYAL_PAIR_NUDGE,
                data = mapOf("engineer_id" to "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"),
            ),
        )
    }

    @Test
    fun `missing required payload field returns null`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )

        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = emptyMap(),
            ),
        )
    }

    @Test
    fun `malformed ids are rejected in current contract`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-5555"),
            ),
        )

        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "%31%31%31%31-2222-3333-4444-555555555555"),
            ),
        )
    }

    @Test
    fun `whitespace-only and empty ids stay rejected`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to " "),
            ),
        )

        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
                data = mapOf("conversation_id" to ""),
            ),
        )
    }

    @Test
    fun `encoded slash path-like ids do not route`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555%2Foops"),
            ),
        )
    }

    @Test
    fun `unknown kind returns null`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = "engineer_auto_suspended_and_refund",
                data = mapOf("anything" to "11111111-2222-3333-4444-555555555555"),
            ),
        )
    }

    @Test
    fun `blank kind and null kind are safely ignored`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = " ",
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )
        assertNull(
            NotificationDeepLink.routeFor(
                kind = null,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )
    }

    @Test
    fun `RPR code boundary rejects more than eight digits`() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-12345678"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_BID_NEW,
                data = mapOf("repair_job_id" to "RPR-12345678"),
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
    fun `contract ids remain uuid-only for contract-kind rows`() {
        assertNull(
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_SLA_BREACH,
                data = mapOf("amc_contract_id" to "RPR-00001"),
            ),
        )

        assertEquals(
            Routes.amcContractDetailRoute("11111111-2222-3333-4444-555555555555"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_SLA_BREACH,
                data = mapOf("amc_contract_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )
    }

    @Test
    fun `engineer payout map stays on job detail route`() {
        assertEquals(
            Routes.repairJobDetailRoute("11111111-2222-3333-4444-555555555555"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ENGINEER_PAYOUT_PROCESSED,
                data = mapOf("repair_job_id" to "11111111-2222-3333-4444-555555555555"),
            ),
        )

        assertEquals(
            Routes.repairJobDetailRoute("RPR-12345678"),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ENGINEER_PAYOUT_FAILED,
                data = mapOf("repair_job_id" to "RPR-12345678"),
            ),
        )
    }

    @Test
    fun `amc visit unassigned intentionally routes to engineer visits list`() {
        assertEquals(
            Routes.ENGINEER_AMC_VISITS,
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_VISIT_UNASSIGNED,
                data = mapOf(
                    "repair_job_id" to "11111111-2222-3333-4444-555555555555",
                    "amc_contract_id" to "99999999-8888-7777-6666-555555555555",
                ),
            ),
        )
    }

    @Test
    fun `documented job lifecycle kinds require the repair job field`() {
        val kinds = listOf(
            NotificationDeepLink.KIND_REPAIR_BID_NEW,
            NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED,
            NotificationDeepLink.KIND_REPAIR_BID_REJECTED,
            NotificationDeepLink.KIND_REPAIR_JOB_CANCELLED,
            NotificationDeepLink.KIND_RATE_ENGINEER,
            NotificationDeepLink.KIND_RATE_HOSPITAL,
            NotificationDeepLink.KIND_COST_REVISION_PROPOSED,
            NotificationDeepLink.KIND_COST_REVISION_APPROVED,
            NotificationDeepLink.KIND_COST_REVISION_REJECTED,
            NotificationDeepLink.KIND_WARRANTY_COVERED,
            NotificationDeepLink.KIND_WARRANTY_FEE_WAIVED,
            NotificationDeepLink.KIND_ESCROW_DISPUTE_OPENED,
            NotificationDeepLink.KIND_ESCROW_ENGINEER_RESPONDED,
            NotificationDeepLink.KIND_ESCROW_DISPUTE_RESOLVED,
            NotificationDeepLink.KIND_AMC_VISIT_ASSIGNED,
            NotificationDeepLink.KIND_AMC_VISIT_ENGINEER_ASSIGNED,
            NotificationDeepLink.KIND_AMC_VISIT_ENGINEER_CHANGED,
            NotificationDeepLink.KIND_ENGINEER_PAYOUT_PROCESSED,
            NotificationDeepLink.KIND_ENGINEER_PAYOUT_FAILED,
        )
        for (kind in kinds) {
            assertEquals(kind, Routes.repairJobDetailRoute(UUID),
                NotificationDeepLink.routeFor(kind, mapOf("repair_job_id" to UUID)))
            assertNull(kind, NotificationDeepLink.routeFor(kind, mapOf("conversation_id" to UUID)))
        }
    }

    @Test
    fun `documented nonprivileged destinations without identifiers`() {
        val destinations = mapOf(
            NotificationDeepLink.KIND_KYC_STATUS_CHANGED to Routes.KYC,
            NotificationDeepLink.KIND_CASH_SURVEY to Routes.HOME,
            NotificationDeepLink.KIND_SPOT_AUDIT_INVITED to Routes.HOME,
            NotificationDeepLink.KIND_COMMISSION_TIER_UPGRADED to Routes.HOME,
            NotificationDeepLink.KIND_ENGINEER_AUTO_SUSPENDED to Routes.PROFILE,
            NotificationDeepLink.KIND_ENGINEER_SUSPENSION_CLEARED to Routes.PROFILE,
            NotificationDeepLink.KIND_AMC_VISIT_UNASSIGNED to Routes.ENGINEER_AMC_VISITS,
        )
        for ((kind, route) in destinations) {
            assertEquals(kind, route, NotificationDeepLink.routeFor(kind, emptyMap()))
        }
    }

    @Test
    fun `required identifier wins over unrelated valid fields`() {
        for ((kind, field) in identifierKinds) {
            val data = mapOf(
                "repair_job_id" to UUID,
                "conversation_id" to UUID,
                "amc_contract_id" to UUID,
                "engineer_id" to UUID,
                "id" to UUID,
            )
            assertNull(kind, NotificationDeepLink.routeFor(kind, data - field))
            assertNull(kind, NotificationDeepLink.routeFor(kind, data + (field to "invalid")))
        }
    }

    @Test
    fun `RPR lower boundary and existing case-insensitivity are preserved`() {
        for (id in listOf("RPR-0", "rpr-1", "RpR-00000000")) {
            assertEquals(id, Routes.repairJobDetailRoute(id),
                NotificationDeepLink.routeFor(NotificationDeepLink.KIND_REPAIR_BID_NEW, mapOf("repair_job_id" to id)))
        }
        for (id in listOf("RPR-", "RPR-123456789", "RPR--1", "RPR-1.0", "RPR-١", "RPR-１")) {
            assertNull(id, NotificationDeepLink.routeFor(NotificationDeepLink.KIND_REPAIR_BID_NEW, mapOf("repair_job_id" to id)))
        }
    }

    @Test
    fun `UUID case and width are checked without trimming or decoding`() {
        val uppercase = UUID.uppercase(java.util.Locale.ROOT)
        assertEquals(Routes.chatRoute(uppercase), NotificationDeepLink.routeFor(
            NotificationDeepLink.KIND_CHAT_MESSAGE_NEW, mapOf("conversation_id" to uppercase)))
        for ((kind, field) in identifierKinds) {
            for (id in listOf(" $UUID", "$UUID ", UUID.dropLast(1), UUID + "0", "{$UUID}", UUID.replace("-", ""), UUID.replace("-", "%2D"))) {
                assertNull("$kind rejects $id", NotificationDeepLink.routeFor(kind, mapOf(field to id)))
            }
        }
    }

    @Test
    fun `control characters path separators query syntax and large IDs are rejected`() {
        val invalidIds = listOf(
            "", " ", "\t", "$UUID\n", "$UUID\r\n", "$UUID\u0000",
            "$UUID/other", "$UUID\\other", "$UUID?role=founder", "$UUID#fragment",
            "../$UUID", "$UUID%2fother", "$UUID%252Fother", "%00$UUID",
            "RPR-1%0a", "RPR-" + "1".repeat(4096), "a".repeat(4096),
        )
        for ((kind, field) in identifierKinds) {
            for (id in invalidIds) {
                assertNull("$kind rejects malformed id length ${id.length}",
                    NotificationDeepLink.routeFor(kind, mapOf(field to id)))
            }
        }
    }

    @Test
    fun `unknown and altered kind strings never infer a destination from valid IDs`() {
        val payload = identifierKinds.map { it.second }.associateWith { UUID }
        val kinds = listOf(
            null, "", "\n", "CHAT_MESSAGE_NEW", " chat_message_new", "chat_message_new ",
            "chat_message_new\u0000", "chat_message_new%00", "chat%5Fmessage_new",
            "order_shipped", "rfq_bid_accepted", "unknown_" + "x".repeat(4096),
        )
        for (kind in kinds) assertNull(NotificationDeepLink.routeFor(kind, payload))
    }

    @Test
    fun `all contract notifications require their own valid UUID`() {
        for (kind in listOf(
            NotificationDeepLink.KIND_AMC_SLA_BREACH,
            NotificationDeepLink.KIND_AMC_VISIT_PENDING_ASSIGNMENT,
            NotificationDeepLink.KIND_AMC_RENEWAL_DUE,
        )) {
            assertEquals(Routes.amcContractDetailRoute(UUID),
                NotificationDeepLink.routeFor(kind, mapOf("amc_contract_id" to UUID)))
            assertNull(NotificationDeepLink.routeFor(kind, emptyMap()))
            assertNull(NotificationDeepLink.routeFor(kind, mapOf("amc_contract_id" to "RPR-1")))
        }
    }

    private companion object {
        const val UUID = "a1b2c3d4-1234-5678-9abc-def012345678"
        val identifierKinds = listOf(
            NotificationDeepLink.KIND_CHAT_MESSAGE_NEW to "conversation_id",
            NotificationDeepLink.KIND_REPAIR_BID_NEW to "repair_job_id",
            NotificationDeepLink.KIND_AMC_SLA_BREACH to "amc_contract_id",
            NotificationDeepLink.KIND_AMC_LOYAL_PAIR_NUDGE to "engineer_id",
        )
    }
}
