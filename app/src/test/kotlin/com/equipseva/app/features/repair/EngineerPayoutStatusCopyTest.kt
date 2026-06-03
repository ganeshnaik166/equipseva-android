package com.equipseva.app.features.repair

import com.equipseva.app.core.data.payouts.JobPayoutStatus
import com.equipseva.app.core.data.payouts.PayoutStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class EngineerPayoutStatusCopyTest {

    private fun status(
        s: PayoutStatus,
        engineer: String? = "Ravi Kumar",
        destination: String? = "ravi@oksbi",
        mode: String? = "UPI",
        utr: String? = null,
        failureReason: String? = null,
    ) = JobPayoutStatus(
        id = "p1",
        amountPaise = 930,
        status = s,
        mode = mode,
        utr = utr,
        failureReason = failureReason,
        destinationLabel = destination,
        engineerName = engineer,
        queuedAt = "2026-06-03T01:00:00Z",
        processedAt = null,
    )

    /* --- titles --- */

    @Test
    fun `hospital reads emphasises the engineer received`() {
        assertEquals("Paid to engineer", engineerPayoutTitle(status(PayoutStatus.Processed), isHospital = true))
    }

    @Test
    fun `engineer reads emphasises their own receipt`() {
        assertEquals("Paid to your account", engineerPayoutTitle(status(PayoutStatus.Processed), isHospital = false))
    }

    @Test
    fun `queued state reads consistent across viewers`() {
        assertEquals("Engineer payout queued", engineerPayoutTitle(status(PayoutStatus.Queued), isHospital = true))
        assertEquals("Your payout is queued", engineerPayoutTitle(status(PayoutStatus.Queued), isHospital = false))
    }

    @Test
    fun `cancelled title is symmetric`() {
        assertEquals("Payout cancelled", engineerPayoutTitle(status(PayoutStatus.Cancelled), isHospital = true))
        assertEquals("Payout cancelled", engineerPayoutTitle(status(PayoutStatus.Cancelled), isHospital = false))
    }

    /* --- subtitles --- */

    @Test
    fun `hospital subtitle on processed names the engineer + destination + mode`() {
        val sub = engineerPayoutSubtitle(status(PayoutStatus.Processed, mode = "UPI"), isHospital = true)
        assertNotNull(sub)
        assertEquals(
            "Ravi Kumar received via UPI to ravi@oksbi.",
            sub,
        )
    }

    @Test
    fun `engineer subtitle on processed names their own destination + mode`() {
        val sub = engineerPayoutSubtitle(status(PayoutStatus.Processed, mode = "IMPS"), isHospital = false)
        assertEquals("Received via IMPS at ravi@oksbi.", sub)
    }

    @Test
    fun `hospital failed subtitle reassures no action needed`() {
        val sub = engineerPayoutSubtitle(status(PayoutStatus.Failed), isHospital = true)
        assertEquals("We'll retry automatically. No action needed from you.", sub)
    }

    @Test
    fun `engineer failed subtitle nudges to fix payout method`() {
        val sub = engineerPayoutSubtitle(status(PayoutStatus.Failed), isHospital = false)
        assertEquals(
            "Re-check your payout method — we'll retry on the next worker tick.",
            sub,
        )
    }

    @Test
    fun `processed subtitle falls back to defaults when fields null`() {
        val sub = engineerPayoutSubtitle(
            status(PayoutStatus.Processed, engineer = null, destination = null, mode = null),
            isHospital = true,
        )
        assertEquals("Engineer received via UPI to their account.", sub)
    }

    @Test
    fun `cancelled subtitle covers both viewers`() {
        assertEquals(
            "Admin cancelled this payout.",
            engineerPayoutSubtitle(status(PayoutStatus.Cancelled), isHospital = true),
        )
        assertEquals(
            "Admin cancelled. Reach out if unexpected.",
            engineerPayoutSubtitle(status(PayoutStatus.Cancelled), isHospital = false),
        )
    }
}
