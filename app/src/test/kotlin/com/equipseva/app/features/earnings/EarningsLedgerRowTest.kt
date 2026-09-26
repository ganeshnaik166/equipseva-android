package com.equipseva.app.features.earnings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * The engineer's money ledger has to be reconcilable against reality: against
 * the visits they did, and against their bank statement.
 */
class EarningsLedgerRowTest {

    // ---- amcEarningRowTitle -------------------------------------------

    @Test fun `each AMC payout row is identified by its visit date`() {
        // Every row used to carry the same "AMC visit" label with the date
        // nowhere on screen, so a dozen AMC payouts read as a dozen identical
        // lines that could not be matched to any visit.
        val first = amcEarningRowTitle("2026-05-11T09:30:00Z", fallback = "AMC visit")
        val second = amcEarningRowTitle("2026-06-14T09:30:00Z", fallback = "AMC visit")
        assertEquals("11 May 2026", first)
        assertEquals("14 Jun 2026", second)
        assertNotEquals(first, second)
    }

    @Test fun `a row with no completion date keeps the label`() {
        assertEquals("AMC visit", amcEarningRowTitle(null, fallback = "AMC visit"))
        assertEquals("AMC visit", amcEarningRowTitle("   ", fallback = "AMC visit"))
    }

    // ---- payoutRowAmountText ------------------------------------------

    @Test fun `transfer amounts are paise-exact`() {
        // amountPaise is what the bank actually moved. Rounding made a
        // ₹1,234.56 UTR read as ₹1,235 — a figure on no statement anywhere.
        assertEquals("₹1,234.56", payoutRowAmountText(123_456L))
        assertEquals("₹2,500.00", payoutRowAmountText(250_000L))
        assertEquals("₹0.99", payoutRowAmountText(99L))
    }

    @Test fun `lakh grouping is Indian`() {
        assertEquals("₹1,00,000.00", payoutRowAmountText(10_000_000L))
    }
}
