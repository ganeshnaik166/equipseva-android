package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1398 PM-calendar status pill. */
class PmCalendarHelpersTest {

    @Test fun `overdue reads Overdue with Danger tone`() {
        assertEquals("Overdue" to PillKind.Danger, pmStatusPillTextAndKind("overdue"))
    }

    @Test fun `due reads Due now with Warn tone`() {
        assertEquals("Due now" to PillKind.Warn, pmStatusPillTextAndKind("due"))
    }

    @Test fun `upcoming reads Upcoming with Info tone`() {
        assertEquals("Upcoming" to PillKind.Info, pmStatusPillTextAndKind("upcoming"))
    }

    @Test fun `scheduled and unknown fall back to Scheduled Neutral`() {
        assertEquals("Scheduled" to PillKind.Neutral, pmStatusPillTextAndKind("scheduled"))
        assertEquals("Scheduled" to PillKind.Neutral, pmStatusPillTextAndKind("something_new"))
    }
}
