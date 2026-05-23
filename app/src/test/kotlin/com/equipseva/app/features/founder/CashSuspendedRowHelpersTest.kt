package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two helpers on the founder cash-suspended-engineers
 * queue row.
 *
 * Critical regions:
 *   * cashSuspendedRowName — null/blank → "Engineer" generic
 *     (matches amcVisitHospitalName pattern; no dev-placeholder
 *     leakage).
 *   * cashSuspendedFlagCountLabel — preserves the "/ 90d" rolling-
 *     window context. Pin so the unit stays intact — load-bearing
 *     context the founder uses to triage.
 */
class CashSuspendedRowHelpersTest {

    // ---- cashSuspendedRowName ----

    @Test fun `present name passes through`() {
        assertEquals("Ravi Kumar", cashSuspendedRowName("Ravi Kumar"))
    }

    @Test fun `null name renders Engineer fallback`() {
        assertEquals("Engineer", cashSuspendedRowName(null))
    }

    @Test fun `blank name renders Engineer fallback`() {
        assertEquals("Engineer", cashSuspendedRowName("  "))
        assertEquals("Engineer", cashSuspendedRowName(""))
    }

    // ---- cashSuspendedFlagCountLabel ----

    @Test fun `composes count with slash 90d unit`() {
        assertEquals("3 flags / 90d", cashSuspendedFlagCountLabel(3))
        assertEquals("5 flags / 90d", cashSuspendedFlagCountLabel(5))
    }

    @Test fun `single flag also uses plural (defensive — trigger requires 3+)`() {
        // Single-flag suspension shouldn't fire (3+ flag trigger),
        // but pin the always-plural shape so a transient race
        // shows "1 flags / 90d" (awkward but not "1 flag / 90d"
        // which would imply a different gate).
        assertEquals("1 flags / 90d", cashSuspendedFlagCountLabel(1))
    }

    @Test fun `slash spacing pinned (space-slash-space)`() {
        // Pin so a refactor doesn't drift to "/90d" or "/ 90d"
        // without spaces — the spacing is intentional for legibility
        // on small phones.
        assertEquals(true, cashSuspendedFlagCountLabel(3).contains(" / 90d"))
    }

    @Test fun `unit literal is 90d (not 90 days)`() {
        // Pin the abbreviated form — pin so a "make it more readable"
        // refactor doesn't expand to "90 days" (which would shift
        // line wraps on small phones).
        val out = cashSuspendedFlagCountLabel(3)
        assertEquals(true, out.endsWith("90d"))
        assertEquals(false, out.endsWith("90 days"))
    }
}
