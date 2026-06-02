package com.equipseva.app.features.earnings

import com.equipseva.app.core.data.payouts.EngineerPayoutRow
import com.equipseva.app.core.data.payouts.PayoutStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class PayoutSubtitleTest {

    private fun row(
        status: PayoutStatus,
        mode: String? = null,
        utr: String? = null,
        failureReason: String? = null,
    ): EngineerPayoutRow = EngineerPayoutRow(
        id = "p1",
        jobNumber = "RPR-00099",
        amountPaise = 930,
        status = status,
        mode = mode,
        utr = utr,
        failureReason = failureReason,
        destinationLabel = "gani@oksbi",
        queuedAt = "2026-06-02T03:12:48Z",
        processedAt = null,
    )

    @Test
    fun `queued subtitle nudges that worker will pick up`() {
        val s = payoutSubtitle(row(PayoutStatus.Queued))
        assertEquals(
            "Will pay automatically after the next worker tick.",
            s,
        )
    }

    @Test
    fun `processed with UTR shows UTR ref`() {
        val s = payoutSubtitle(row(PayoutStatus.Processed, utr = "REF123", mode = "UPI"))
        // UTR wins over mode — UTR is the bank-of-record reference.
        assertEquals("Paid · UTR REF123", s)
    }

    @Test
    fun `processed without UTR falls back to mode`() {
        val s = payoutSubtitle(row(PayoutStatus.Processed, mode = "IMPS"))
        assertEquals("Paid · via IMPS", s)
    }

    @Test
    fun `processed with neither UTR nor mode is still readable`() {
        val s = payoutSubtitle(row(PayoutStatus.Processed))
        assertEquals("Paid", s)
    }

    @Test
    fun `failed with reason surfaces the reason verbatim`() {
        val s = payoutSubtitle(row(PayoutStatus.Failed, failureReason = "Invalid VPA"))
        assertEquals("Failed — Invalid VPA", s)
    }

    @Test
    fun `failed without reason still nudges engineer to check method`() {
        val s = payoutSubtitle(row(PayoutStatus.Failed))
        assertEquals("Failed — re-check your payout method.", s)
    }

    @Test
    fun `cancelled is explicit about admin source`() {
        assertEquals("Cancelled by admin.", payoutSubtitle(row(PayoutStatus.Cancelled)))
    }

    @Test
    fun `processing carries the in-flight expectation`() {
        val s = payoutSubtitle(row(PayoutStatus.Processing))
        assertNotNull(s)
        assertEquals("Sent to your bank — waiting for confirmation.", s)
    }
}
