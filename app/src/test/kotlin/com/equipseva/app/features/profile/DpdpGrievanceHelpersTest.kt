package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [DpdpGrievanceScreen] (round3776) — the
 * first Android client of the round485 `file_dpdp_grievance` /
 * `my_grievances` RPCs (DPDP Act 2023 grievance redressal).
 */
class DpdpGrievanceHelpersTest {

    @Test fun `known grievance types map to plain-English labels`() {
        assertEquals("Access my data", dpdpGrievanceTypeLabel("access_request"))
        assertEquals("Delete my data", dpdpGrievanceTypeLabel("deletion_request"))
        assertEquals("Correct my data", dpdpGrievanceTypeLabel("correction_request"))
        assertEquals("Export my data", dpdpGrievanceTypeLabel("data_portability"))
        assertEquals("Withdraw consent", dpdpGrievanceTypeLabel("consent_withdrawal"))
        assertEquals("File a complaint", dpdpGrievanceTypeLabel("complaint"))
    }

    @Test fun `a wire type outside the self-service chip set still renders readable`() {
        // data_breach_notification is a real server-side grievance_type
        // (third-party breach reports) but deliberately not offered as
        // a self-service chip — must still render safely if it ever
        // shows up in a user's own history.
        assertEquals("Data breach notification", dpdpGrievanceTypeLabel("data_breach_notification"))
    }

    @Test fun `status maps to the expected pill tone`() {
        assertEquals("Open" to PillKind.Warn, dpdpGrievanceStatusLabelAndKind("open"))
        assertEquals("In review" to PillKind.Info, dpdpGrievanceStatusLabelAndKind("in_review"))
        assertEquals("Resolved" to PillKind.Success, dpdpGrievanceStatusLabelAndKind("resolved"))
        assertEquals("Escalated" to PillKind.Danger, dpdpGrievanceStatusLabelAndKind("escalated"))
        assertEquals("Rejected" to PillKind.Neutral, dpdpGrievanceStatusLabelAndKind("rejected"))
    }

    @Test fun `unknown status falls back to capitalised label + Neutral`() {
        assertEquals("Future_state" to PillKind.Neutral, dpdpGrievanceStatusLabelAndKind("future_state"))
    }
}
