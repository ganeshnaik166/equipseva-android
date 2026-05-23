package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * v2 / D / C-series push-kind coverage extends the existing
 * NotificationDeepLinkTest with the additional kinds shipped after
 * the v1 baseline: rating reminders, cost-revision lifecycle,
 * warranty notifications, cash-survey + spot-audit, escrow disputes,
 * AMC visit / renewal lifecycle, and the admin-side alert kinds.
 *
 * The class is split so the original baseline file stays focused on
 * the resolver-shape contract; this file covers the kind→route
 * matrix exhaustively so a future server-side push trigger addition
 * is paired with a route mapping.
 */
class NotificationDeepLinkV2Test {

    private val jobUuid = "11111111-2222-3333-4444-555555555555"
    private val convUuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    private val engineerUuid = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
    private val amcUuid = "cccccccc-dddd-eeee-ffff-000000000000"

    // ---- rating reminders → repair detail ----

    @Test fun `rate_engineer resolves to repair job detail`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RATE_ENGINEER,
            data = mapOf("repair_job_id" to jobUuid),
        )
        assertEquals(Routes.repairJobDetailRoute(jobUuid), route)
    }

    @Test fun `rate_hospital resolves to repair job detail`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RATE_HOSPITAL,
            data = mapOf("repair_job_id" to jobUuid),
        )
        assertEquals(Routes.repairJobDetailRoute(jobUuid), route)
    }

    // ---- cost revision lifecycle → repair detail ----

    @Test fun `cost_revision_proposed resolves to repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_COST_REVISION_PROPOSED,
                data = mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    @Test fun `cost_revision_approved + _rejected both resolve to repair job detail`() {
        listOf(
            NotificationDeepLink.KIND_COST_REVISION_APPROVED,
            NotificationDeepLink.KIND_COST_REVISION_REJECTED,
        ).forEach { kind ->
            assertEquals(
                Routes.repairJobDetailRoute(jobUuid),
                NotificationDeepLink.routeFor(
                    kind = kind,
                    data = mapOf("repair_job_id" to jobUuid),
                ),
            )
        }
    }

    // ---- warranty → repair detail ----

    @Test fun `warranty_covered + warranty_fee_waived resolve to repair job detail`() {
        listOf(
            NotificationDeepLink.KIND_WARRANTY_COVERED,
            NotificationDeepLink.KIND_WARRANTY_FEE_WAIVED,
        ).forEach { kind ->
            assertEquals(
                Routes.repairJobDetailRoute(jobUuid),
                NotificationDeepLink.routeFor(
                    kind = kind,
                    data = mapOf("repair_job_id" to jobUuid),
                ),
            )
        }
    }

    // ---- repair_job_cancelled also routes via repair_job_id ----

    @Test fun `repair_job_cancelled routes to repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_REPAIR_JOB_CANCELLED,
                data = mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    // ---- AMC contract routes ----

    @Test fun `amc_sla_breach resolves to AMC contract detail`() {
        assertEquals(
            Routes.amcContractDetailRoute(amcUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_SLA_BREACH,
                data = mapOf("amc_contract_id" to amcUuid),
            ),
        )
    }

    @Test fun `amc_renewal_due resolves to AMC contract detail`() {
        assertEquals(
            Routes.amcContractDetailRoute(amcUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_RENEWAL_DUE,
                data = mapOf("amc_contract_id" to amcUuid),
            ),
        )
    }

    @Test fun `amc_visit_pending_assignment resolves to AMC contract detail`() {
        assertEquals(
            Routes.amcContractDetailRoute(amcUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_VISIT_PENDING_ASSIGNMENT,
                data = mapOf("amc_contract_id" to amcUuid),
            ),
        )
    }

    // ---- AMC visit lifecycle → repair detail (visit IS a repair_job) ----

    @Test fun `amc_visit_assigned + amc_visit_engineer_assigned + _changed resolve via repair_job_id`() {
        listOf(
            NotificationDeepLink.KIND_AMC_VISIT_ASSIGNED,
            NotificationDeepLink.KIND_AMC_VISIT_ENGINEER_ASSIGNED,
            NotificationDeepLink.KIND_AMC_VISIT_ENGINEER_CHANGED,
        ).forEach { kind ->
            assertEquals(
                Routes.repairJobDetailRoute(jobUuid),
                NotificationDeepLink.routeFor(
                    kind = kind,
                    data = mapOf("repair_job_id" to jobUuid),
                ),
            )
        }
    }

    // ---- escrow dispute lifecycle ----

    @Test fun `escrow_dispute_opened resolves to repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ESCROW_DISPUTE_OPENED,
                data = mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    @Test fun `escrow_dispute_resolved resolves to repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ESCROW_DISPUTE_RESOLVED,
                data = mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    @Test fun `escrow_engineer_responded resolves to repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ESCROW_ENGINEER_RESPONDED,
                data = mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    // ---- AMC loyal-pair nudge → engineer public profile ----

    @Test fun `amc_loyal_pair_nudge resolves to engineer public profile`() {
        assertEquals(
            Routes.engineerPublicProfileRoute(engineerUuid),
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_AMC_LOYAL_PAIR_NUDGE,
                data = mapOf("engineer_id" to engineerUuid),
            ),
        )
    }

    // ---- single-screen kinds (no id required) ----

    @Test fun `kyc_status_changed resolves to KYC screen with no payload`() {
        assertEquals(
            Routes.KYC,
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_KYC_STATUS_CHANGED,
                data = emptyMap(),
            ),
        )
    }

    @Test fun `cash_survey + spot_audit_invited + commission_tier_upgraded all land on Home`() {
        listOf(
            NotificationDeepLink.KIND_CASH_SURVEY,
            NotificationDeepLink.KIND_SPOT_AUDIT_INVITED,
            NotificationDeepLink.KIND_COMMISSION_TIER_UPGRADED,
        ).forEach { kind ->
            assertEquals(
                Routes.HOME,
                NotificationDeepLink.routeFor(kind = kind, data = emptyMap()),
            )
        }
    }

    @Test fun `engineer_auto_suspended lands on Profile`() {
        assertEquals(
            Routes.PROFILE,
            NotificationDeepLink.routeFor(
                kind = NotificationDeepLink.KIND_ENGINEER_AUTO_SUSPENDED,
                data = emptyMap(),
            ),
        )
    }

    // ---- admin-side queue alerts ----

    @Test fun `admin escrow dispute + AMC escalation + auto-suspend land on founder queues`() {
        val expectations = mapOf(
            NotificationDeepLink.KIND_ADMIN_ENGINEER_AUTO_SUSPENDED to Routes.FOUNDER_CASH_SUSPENDED,
            NotificationDeepLink.KIND_ADMIN_ESCROW_DISPUTE_OPENED to Routes.FOUNDER_ESCROW_DISPUTES,
            NotificationDeepLink.KIND_AMC_ADMIN_ESCALATION_RAISED to Routes.FOUNDER_AMC_ESCALATIONS,
        )
        expectations.forEach { (kind, expected) ->
            assertEquals(
                "kind=$kind",
                expected,
                NotificationDeepLink.routeFor(kind = kind, data = emptyMap()),
            )
        }
    }

    // ---- missing-id sad paths ----

    @Test fun `repair_job_id missing yields null for repair-job-routed kinds`() {
        // The kind is recognised but the data map doesn't carry the
        // expected id. Caller treats null as "open inbox instead".
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RATE_ENGINEER,
            data = emptyMap(),
        )
        assertNull(route)
    }

    @Test fun `non-UUID repair_job_id yields null (strict gate)`() {
        // Critical: a garbage id from a corrupt payload must NOT navigate
        // into the detail screen and crash on backstack pop. UUID gate
        // pin the contract.
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RATE_ENGINEER,
            data = mapOf("repair_job_id" to "not-a-uuid"),
        )
        assertNull(route)
    }

    @Test fun `RPR job code IS accepted on repair-job-routed kinds (per PR 651)`() {
        // The repository's fetchById accepts both UUID id and the
        // public RPR-NNNNN job_number, so the deep-link resolver
        // matches that for the same kinds.
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_RATE_ENGINEER,
            data = mapOf("repair_job_id" to "RPR-00027"),
        )
        assertEquals(Routes.repairJobDetailRoute("RPR-00027"), route)
    }

    @Test fun `chat_message_new with missing conversation_id yields null`() {
        val route = NotificationDeepLink.routeFor(
            kind = NotificationDeepLink.KIND_CHAT_MESSAGE_NEW,
            data = mapOf("repair_job_id" to convUuid),
        )
        assertNull(route)
    }
}
