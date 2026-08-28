package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the r1502 deep-link additions — four server-emitted kinds that
 * previously fell to the inbox fallback on tap (found by diffing the
 * migrations' INSERT INTO notifications kinds against the client map):
 * payout processed/failed → job detail (its payout status card is the exact
 * surface); suspension cleared → Profile (symmetric with auto_suspended);
 * AMC visit unassigned → the OLD engineer's visits list (NOT the job they
 * no longer own).
 */
class NotificationDeepLinkPayoutTest {

    private val jobUuid = "123e4567-e89b-42d3-a456-426614174000"

    @Test fun `payout processed routes to the repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_ENGINEER_PAYOUT_PROCESSED,
                mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    @Test fun `payout failed routes to the repair job detail`() {
        assertEquals(
            Routes.repairJobDetailRoute(jobUuid),
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_ENGINEER_PAYOUT_FAILED,
                mapOf("repair_job_id" to jobUuid),
            ),
        )
    }

    @Test fun `payout kinds accept the RPR job-number form too`() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-00040"),
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_ENGINEER_PAYOUT_FAILED,
                mapOf("repair_job_id" to "RPR-00040"),
            ),
        )
    }

    @Test fun `payout kind with junk id falls back to inbox (null)`() {
        assertNull(
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_ENGINEER_PAYOUT_FAILED,
                mapOf("repair_job_id" to "not-a-uuid"),
            ),
        )
    }

    @Test fun `suspension cleared routes to Profile like its auto-suspended sibling`() {
        assertEquals(
            Routes.PROFILE,
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_ENGINEER_SUSPENSION_CLEARED,
                emptyMap(),
            ),
        )
    }

    @Test fun `amc visit unassigned routes to the engineer visits list, not the lost job`() {
        assertEquals(
            Routes.ENGINEER_AMC_VISITS,
            NotificationDeepLink.routeFor(
                NotificationDeepLink.KIND_AMC_VISIT_UNASSIGNED,
                mapOf("repair_job_id" to jobUuid, "amc_contract_id" to jobUuid),
            ),
        )
    }
}
