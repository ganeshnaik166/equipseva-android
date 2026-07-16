package com.equipseva.app.core.data.consent

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pins for the r1415 file-a-grievance helpers. */
class GrievanceFilingHelpersTest {

    @Test fun `description validation mirrors the server rules`() {
        assertEquals("Please describe your request.", grievanceDescriptionError(""))
        assertEquals("Please describe your request.", grievanceDescriptionError("   "))
        // 9 trimmed chars -> too short
        assertTrue(grievanceDescriptionError("123456789")!!.contains("at least 10"))
        assertNull(grievanceDescriptionError("This is a valid data-rights request."))
        assertTrue(grievanceDescriptionError("x".repeat(5001))!!.contains("under 5000"))
    }

    @Test fun `filable types are the round-485 user-facing subset`() {
        assertEquals(
            listOf(
                "access_request",
                "correction_request",
                "deletion_request",
                "data_portability",
                "consent_withdrawal",
                "complaint",
            ),
            FILABLE_GRIEVANCE_TYPES,
        )
    }

    @Test fun `new grievance type labels resolve`() {
        assertEquals("Data portability request", grievanceTypeLabel("data_portability"))
        assertEquals("Complaint", grievanceTypeLabel("complaint"))
    }
}
