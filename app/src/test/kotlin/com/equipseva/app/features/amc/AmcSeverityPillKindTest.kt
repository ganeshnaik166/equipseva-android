package com.equipseva.app.features.amc

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

class AmcSeverityPillKindTest {

    @Test fun `emergency severity maps to Danger`() {
        // Critical pin — emergency-visit SLA breaches are the most
        // urgent (equipment is presumably keeping someone alive).
        assertEquals(
            PillKind.Danger,
            amcSeverityPillKind("emergency"),
        )
    }

    @Test fun `standard severity maps to Warn`() {
        assertEquals(
            PillKind.Warn,
            amcSeverityPillKind("standard"),
        )
    }

    @Test fun `null severity falls through to Warn (defensive)`() {
        assertEquals(
            PillKind.Warn,
            amcSeverityPillKind(null),
        )
    }

    @Test fun `unknown severity falls through to Warn (forward-compat)`() {
        assertEquals(
            PillKind.Warn,
            amcSeverityPillKind("future_critical"),
        )
    }

    @Test fun `case-sensitive — Emergency capital E falls through to Warn`() {
        // Pin exact-match — wire CHECK is lowercase. Case-insensitive
        // would mask server-side enum drift.
        assertEquals(
            PillKind.Warn,
            amcSeverityPillKind("Emergency"),
        )
    }
}
