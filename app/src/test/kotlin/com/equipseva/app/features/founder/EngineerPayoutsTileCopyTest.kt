package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

class EngineerPayoutsTileCopyTest {

    private fun sum(
        queued: Int = 0,
        queuedPaise: Long = 0,
        processing: Int = 0,
        failed: Int = 0,
        failedPaise: Long = 0,
    ) = FounderRepository.EngineerPayoutsSummary(
        queuedCount = queued,
        queuedAmountPaise = queuedPaise,
        processingCount = processing,
        failedCount = failed,
        failedAmountPaise = failedPaise,
        lastProcessedAt = null,
    )

    /* -- title -- */

    @Test
    fun `single queued reads in singular`() {
        assertEquals("1 payout queued", engineerPayoutsTileTitle(sum(queued = 1, queuedPaise = 930)))
    }

    @Test
    fun `multiple queued reads in plural`() {
        assertEquals("3 payouts queued", engineerPayoutsTileTitle(sum(queued = 3, queuedPaise = 2790)))
    }

    @Test
    fun `failed only reads failed`() {
        assertEquals("2 payouts failed", engineerPayoutsTileTitle(sum(failed = 2, failedPaise = 1860)))
    }

    @Test
    fun `mixed failed+queued shows both counts`() {
        assertEquals("1 failed · 2 queued", engineerPayoutsTileTitle(sum(failed = 1, failedPaise = 930, queued = 2, queuedPaise = 1860)))
    }

    /* -- subtitle -- */

    @Test
    fun `subtitle shows queued rupees when queued only`() {
        val s = sum(queued = 3, queuedPaise = 2790)
        assertEquals("₹27.90 queued", engineerPayoutsTileSubtitle(s, 27.90, 0.0))
    }

    @Test
    fun `subtitle joins queued and failed rupees`() {
        val s = sum(queued = 1, queuedPaise = 930, failed = 2, failedPaise = 1860)
        assertEquals("₹9.30 queued · ₹18.60 failed", engineerPayoutsTileSubtitle(s, 9.30, 18.60))
    }

    @Test
    fun `subtitle adds processing count tail when present`() {
        val s = sum(queued = 1, queuedPaise = 930, processing = 2)
        assertEquals("₹9.30 queued · 2 in flight", engineerPayoutsTileSubtitle(s, 9.30, 0.0))
    }

    @Test
    fun `subtitle for processing-only is just the in-flight tail`() {
        // hasActionableWork would be false here so the tile wouldn't render,
        // but the helper should still return clean copy if called.
        val s = sum(processing = 1)
        assertEquals("1 in flight", engineerPayoutsTileSubtitle(s, 0.0, 0.0))
    }
}
