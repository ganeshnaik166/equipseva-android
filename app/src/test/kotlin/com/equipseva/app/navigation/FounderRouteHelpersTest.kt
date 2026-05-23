package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the founder admin route helpers — drill-down routes that
 * receive an id via path segment. The path-segment form (vs. query)
 * means the receiving screen reads the id from the path arg key
 * registered in the NavGraph. A refactor that flipped path to query
 * would silently break the deep link.
 */
class FounderRouteHelpersTest {

    @Test fun `kyc review route appends user id as path segment`() {
        assertEquals(
            "founder/kyc/review/uid-abc-123",
            Routes.founderKycReviewRoute("uid-abc-123"),
        )
    }

    @Test fun `cash flag history route appends engineer id as path segment`() {
        assertEquals(
            "founder/cash_flag_history/eng-abc-123",
            Routes.founderCashFlagHistoryRoute("eng-abc-123"),
        )
    }

    @Test fun `escrow dispute detail route appends escrow id as path segment`() {
        assertEquals(
            "founder/escrow_dispute_detail/escrow-abc-123",
            Routes.founderEscrowDisputeDetailRoute("escrow-abc-123"),
        )
    }

    @Test fun `amc escalation detail route appends escalation id as path segment`() {
        assertEquals(
            "founder/amc_escalation_detail/esc-abc-123",
            Routes.founderAmcEscalationDetailRoute("esc-abc-123"),
        )
    }

    @Test fun `engineer public profile route appends engineer id as path segment`() {
        assertEquals(
            "engineers/public/eng-abc-123",
            Routes.engineerPublicProfileRoute("eng-abc-123"),
        )
    }

    @Test fun `chat detail route appends conversation id as path segment`() {
        assertEquals(
            "chat/detail/conv-abc-123",
            Routes.chatRoute("conv-abc-123"),
        )
    }

    @Test fun `repair job detail route appends jobId as path segment`() {
        assertEquals(
            "repair/detail/job-abc-123",
            Routes.repairJobDetailRoute("job-abc-123"),
        )
    }
}
