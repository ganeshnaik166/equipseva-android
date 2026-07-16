package com.equipseva.app.features.org

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1448 organization-detail verification pill. */
class OrganizationDetailHelpersTest {

    @Test fun `verification pill maps states (case-insensitive)`() {
        assertEquals("Verified" to PillKind.Success, orgVerificationPill("verified"))
        assertEquals("Verified" to PillKind.Success, orgVerificationPill("VERIFIED"))
        assertEquals("Rejected" to PillKind.Danger, orgVerificationPill("rejected"))
    }

    @Test fun `null or blank status reads Pending`() {
        assertEquals("Pending" to PillKind.Warn, orgVerificationPill(null))
        assertEquals("Pending" to PillKind.Warn, orgVerificationPill(""))
        assertEquals("Pending" to PillKind.Warn, orgVerificationPill("pending"))
    }

    @Test fun `unknown status de-snakes with Neutral`() {
        assertEquals("Under review" to PillKind.Neutral, orgVerificationPill("under_review"))
    }
}
