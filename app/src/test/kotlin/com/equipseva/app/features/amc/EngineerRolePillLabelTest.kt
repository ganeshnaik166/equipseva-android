package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the primary/fallback engineer pill label on the AMC-detail
 * overview tab. The wording is role-aware semantics — pin so a
 * refactor to "Lead/Backup" doesn't change the engineer's mental
 * model of their rotation status.
 */
class EngineerRolePillLabelTest {

    @Test fun `primary true reads Primary engineer`() {
        assertEquals("Primary engineer", engineerRolePillLabel(true))
    }

    @Test fun `primary false reads Fallback engineer`() {
        // Pin "Fallback" not "Backup" or "Secondary". The wire
        // semantics distinguish "primary" (lead, gets first call)
        // from "fallback" (gets called when primary declines).
        assertEquals("Fallback engineer", engineerRolePillLabel(false))
    }

    @Test fun `both labels end with the word engineer`() {
        // Pin the engineer suffix — load-bearing for the pill to
        // read as a role-on-this-contract, not a generic status.
        assertEquals(true, engineerRolePillLabel(true).endsWith(" engineer"))
        assertEquals(true, engineerRolePillLabel(false).endsWith(" engineer"))
    }

    @Test fun `labels use lowercase engineer not Engineer`() {
        // Pin — the pill typography lowercases the second word.
        assertEquals(true, engineerRolePillLabel(true).contains(" engineer"))
        assertEquals(false, engineerRolePillLabel(true).contains(" Engineer"))
    }
}
