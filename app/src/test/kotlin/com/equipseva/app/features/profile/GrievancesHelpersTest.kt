package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1403 grievance status pill. */
class GrievancesHelpersTest {

    @Test fun `open reads Open with Warn tone`() {
        assertEquals("Open" to PillKind.Warn, grievanceStatusPillTextAndKind("open"))
    }

    @Test fun `in_review reads In review with Info tone`() {
        assertEquals("In review" to PillKind.Info, grievanceStatusPillTextAndKind("in_review"))
    }

    @Test fun `resolved reads Resolved with Success tone`() {
        assertEquals("Resolved" to PillKind.Success, grievanceStatusPillTextAndKind("resolved"))
    }

    @Test fun `escalated reads Escalated with Danger tone`() {
        assertEquals("Escalated" to PillKind.Danger, grievanceStatusPillTextAndKind("escalated"))
    }

    @Test fun `unknown status de-snakes with Neutral tone`() {
        assertEquals("Reopened" to PillKind.Neutral, grievanceStatusPillTextAndKind("reopened"))
    }
}
