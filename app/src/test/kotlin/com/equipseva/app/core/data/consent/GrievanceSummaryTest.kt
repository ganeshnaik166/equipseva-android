package com.equipseva.app.core.data.consent

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1403 grievance type labels. */
class GrievanceSummaryTest {

    @Test fun `known grievance types map to labels`() {
        assertEquals("Data access request", grievanceTypeLabel("access_request"))
        assertEquals("Data deletion request", grievanceTypeLabel("deletion_request"))
        assertEquals("Data breach report", grievanceTypeLabel("breach_report"))
    }

    @Test fun `unknown grievance type de-snakes and capitalises`() {
        assertEquals("Portability request", grievanceTypeLabel("portability_request"))
    }
}
