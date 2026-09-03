package com.equipseva.app.features.amc

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [HospitalPortalScreen] (round3778) —
 * the first Android client of the round1395 Hospital Portal v2
 * self-service backend.
 */
class HospitalPortalHelpersTest {

    @Test fun `known request kinds map to readable labels`() {
        assertEquals("Upgrade AMC tier", hospitalPortalRequestKindLabel("tier_upgrade"))
        assertEquals("Downgrade AMC tier", hospitalPortalRequestKindLabel("tier_downgrade"))
        assertEquals("Cancel contract", hospitalPortalRequestKindLabel("contract_cancel"))
        assertEquals("Transfer ownership", hospitalPortalRequestKindLabel("transfer_ownership"))
    }

    @Test fun `unknown request kind falls back to humanised raw string`() {
        assertEquals("Some future kind", hospitalPortalRequestKindLabel("some_future_kind"))
    }

    @Test fun `known dispute kinds map to readable labels`() {
        assertEquals("Billing dispute", hospitalPortalDisputeKindLabel("billing_dispute"))
        assertEquals("SLA breach", hospitalPortalDisputeKindLabel("sla_breach"))
        assertEquals("Engineer behavior", hospitalPortalDisputeKindLabel("engineer_behavior"))
    }

    @Test fun `unknown dispute kind falls back to humanised raw string`() {
        assertEquals("Some future kind", hospitalPortalDisputeKindLabel("some_future_kind"))
    }

    @Test fun `request status maps to expected pill tone`() {
        assertEquals("Submitted" to PillKind.Warn, hospitalPortalRequestStatusLabelAndKind("submitted"))
        assertEquals("Under review" to PillKind.Info, hospitalPortalRequestStatusLabelAndKind("under_review"))
        assertEquals("Approved" to PillKind.Success, hospitalPortalRequestStatusLabelAndKind("approved"))
        assertEquals("Rejected" to PillKind.Danger, hospitalPortalRequestStatusLabelAndKind("rejected"))
        assertEquals("Cancelled" to PillKind.Neutral, hospitalPortalRequestStatusLabelAndKind("cancelled_by_hospital"))
        assertEquals("Expired" to PillKind.Neutral, hospitalPortalRequestStatusLabelAndKind("expired"))
    }

    @Test fun `dispute status maps to expected pill tone`() {
        assertEquals("Submitted" to PillKind.Warn, hospitalPortalDisputeStatusLabelAndKind("submitted"))
        assertEquals("Mediation requested" to PillKind.Info, hospitalPortalDisputeStatusLabelAndKind("mediation_requested"))
        assertEquals("Accepted" to PillKind.Success, hospitalPortalDisputeStatusLabelAndKind("accepted"))
        assertEquals("Escalated" to PillKind.Danger, hospitalPortalDisputeStatusLabelAndKind("escalated"))
        assertEquals("Withdrawn" to PillKind.Neutral, hospitalPortalDisputeStatusLabelAndKind("withdrawn"))
    }

    @Test fun `unknown status falls back to capitalised label + Neutral for both maps`() {
        assertEquals("Mystery" to PillKind.Neutral, hospitalPortalRequestStatusLabelAndKind("mystery"))
        assertEquals("Mystery" to PillKind.Neutral, hospitalPortalDisputeStatusLabelAndKind("mystery"))
    }
}
