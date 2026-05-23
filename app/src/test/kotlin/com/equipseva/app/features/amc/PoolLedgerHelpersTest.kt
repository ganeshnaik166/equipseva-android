package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the AMC pool-ledger row helpers used to render the contract's
 * payment ledger:
 *
 *   * isPoolLedgerCredit — drives the +/- sign and green/red tint.
 *     Critical: a top-up that mis-renders as a debit makes a hospital
 *     think their pool balance dropped instead of grew.
 *   * poolLedgerLabel — disambiguates the `credit` kind into "SLA
 *     credit" (when sourced from an SLA breach refund) vs "Top-up"
 *     (manual hospital payment). Pin so the breach-id branch
 *     doesn't silently regress to a generic "Credit" label.
 */
class PoolLedgerHelpersTest {

    // ---- isPoolLedgerCredit ----

    @Test fun `credit ledger kind is a credit (+ green)`() {
        assertTrue(isPoolLedgerCredit("credit"))
    }

    @Test fun `refund ledger kind is a credit too (pool grows)`() {
        // A refund (e.g. SLA breach refund back to pool) increases
        // the hospital's pool balance — pin so it stays grouped with
        // top-ups, not debits.
        assertTrue(isPoolLedgerCredit("refund"))
    }

    @Test fun `debit ledger kind is NOT a credit`() {
        assertFalse(isPoolLedgerCredit("debit"))
    }

    @Test fun `unknown ledger kind is NOT a credit (conservative default)`() {
        // Forward-compat: if the server adds a new kind, default to
        // "not credit" so the row colour-codes as a debit. Better to
        // under-report a green than over-promise.
        assertFalse(isPoolLedgerCredit("future_kind"))
    }

    @Test fun `case-sensitive match (wire format is lowercase)`() {
        assertFalse(isPoolLedgerCredit("Credit"))
        assertFalse(isPoolLedgerCredit("REFUND"))
    }

    // ---- poolLedgerLabel ----

    @Test fun `credit with NO source-breach renders as Top-up (manual payment)`() {
        assertEquals("Top-up", poolLedgerLabel("credit", sourceBreachId = null))
    }

    @Test fun `credit WITH a source-breach renders as SLA credit (automated)`() {
        // PR-C4 SLA breach refunds the per-visit fee back to the
        // pool; the row must distinguish from a manual top-up so the
        // hospital can audit the trail.
        assertEquals(
            "SLA credit",
            poolLedgerLabel("credit", sourceBreachId = "breach-1"),
        )
    }

    @Test fun `debit always renders as Visit fair share`() {
        // Debit only fires when a visit is logged; pin the copy.
        assertEquals(
            "Visit fair share",
            poolLedgerLabel("debit", sourceBreachId = null),
        )
    }

    @Test fun `refund renders as Refund (sourceBreachId ignored on refund)`() {
        // Refund's label is always "Refund" — sourceBreachId is
        // informational, not a label modifier. Pin so a future
        // refactor doesn't accidentally split on breach-id here too.
        assertEquals(
            "Refund",
            poolLedgerLabel("refund", sourceBreachId = "breach-1"),
        )
    }

    @Test fun `unknown kind falls back to first-letter-capitalised wire value`() {
        // Server-side enum can grow; ensure unknown kinds still
        // render a readable label rather than the raw snake_case.
        assertEquals(
            "Future_kind",
            poolLedgerLabel("future_kind", sourceBreachId = null),
        )
    }

    @Test fun `empty kind doesn't crash and yields empty label`() {
        // Defensive — never let a malformed payload NPE the row.
        assertEquals("", poolLedgerLabel("", sourceBreachId = null))
    }
}
