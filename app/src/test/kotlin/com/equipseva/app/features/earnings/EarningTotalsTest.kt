package com.equipseva.app.features.earnings

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the earnings screen's pure aggregation: buildEarningRows +
 * computeEarningTotals. These were pulled out of EarningsViewModel.load
 * so we could test the rupee-bucket math without standing up Supabase.
 * A regression either double-counts a job (engineer expects a payout
 * twice) or counts a missing job as pending (inflated expectations).
 */
class EarningTotalsTest {

    @Test fun `buildEarningRows zips bids with jobs and preserves order`() {
        val bidA = bid("ba", jobId = "j1", amount = 1000.0)
        val bidB = bid("bb", jobId = "j2", amount = 2000.0)
        val jobs = mapOf("j1" to job("j1"), "j2" to job("j2"))
        val rows = buildEarningRows(listOf(bidA, bidB), jobs)
        assertEquals(2, rows.size)
        assertSame(bidA, rows[0].bid)
        assertSame(jobs["j1"], rows[0].job)
        assertSame(bidB, rows[1].bid)
        assertSame(jobs["j2"], rows[1].job)
    }

    @Test fun `buildEarningRows leaves unresolved jobs as null instead of dropping the bid`() {
        // The engineer should still see the bid row even if the job was
        // server-side deleted or RLS hides it — the null-job hint is the
        // UI's cue to surface a "needs investigation" badge.
        val resolved = bid("ba", jobId = "j1")
        val orphan = bid("bb", jobId = "missing")
        val rows = buildEarningRows(listOf(resolved, orphan), mapOf("j1" to job("j1")))
        assertEquals(2, rows.size)
        assertNull(rows[1].job)
        assertSame(orphan, rows[1].bid)
    }

    @Test fun `buildEarningRows on empty input is empty`() {
        assertTrue(buildEarningRows(emptyList(), emptyMap()).isEmpty())
    }

    @Test fun `paid sums Completed-job rupees only`() {
        val rows = listOf(
            row(amount = 1000.0, status = RepairJobStatus.Completed),
            row(amount = 500.0, status = RepairJobStatus.Completed),
            row(amount = 2000.0, status = RepairJobStatus.InProgress),
        )
        val totals = computeEarningTotals(rows)
        assertEquals(1500.0, totals.paid, 0.0001)
        assertEquals(2000.0, totals.pending, 0.0001)
    }

    @Test fun `pending bucket includes every non-Completed status`() {
        // Cancelled, Disputed, Requested etc all fall into pending —
        // the screen treats anything that isn't a settled completion
        // as "still owed to me, maybe".
        val rows = listOf(
            row(amount = 100.0, status = RepairJobStatus.Requested),
            row(amount = 200.0, status = RepairJobStatus.Assigned),
            row(amount = 300.0, status = RepairJobStatus.EnRoute),
            row(amount = 400.0, status = RepairJobStatus.InProgress),
            row(amount = 500.0, status = RepairJobStatus.Cancelled),
            row(amount = 600.0, status = RepairJobStatus.Disputed),
            row(amount = 700.0, status = RepairJobStatus.Unknown),
        )
        val totals = computeEarningTotals(rows)
        assertEquals(0.0, totals.paid, 0.0001)
        assertEquals(2800.0, totals.pending, 0.0001)
    }

    @Test fun `rows with a null job are dropped from both buckets`() {
        // The "engineer was paid twice"-style bug here used to be: missing
        // job → treated as pending → engineer expected a payout that
        // would never arrive. Pin that null jobs contribute zero to both
        // totals.
        val rows = listOf(
            row(amount = 1000.0, status = RepairJobStatus.Completed),
            EarningsViewModel.EarningRow(
                bid = bid("orphan", jobId = "missing", amount = 9999.0),
                job = null,
            ),
        )
        val totals = computeEarningTotals(rows)
        assertEquals(1000.0, totals.paid, 0.0001)
        assertEquals(0.0, totals.pending, 0.0001)
    }

    @Test fun `empty rows produces a zero-zero total`() {
        val totals = computeEarningTotals(emptyList())
        assertEquals(0.0, totals.paid, 0.0001)
        assertEquals(0.0, totals.pending, 0.0001)
    }

    @Test fun `accepted-bid amount is what flows into the bucket, not estimated cost`() {
        // The engineer is paid the amount they bid (`bids.amount_rupees`),
        // not the job's estimated_cost field. Pin that distinction — a
        // refactor that read job.estimatedCostRupees instead would
        // silently misreport every engineer's earnings.
        val rows = listOf(
            EarningsViewModel.EarningRow(
                bid = bid("b1", jobId = "j1", amount = 1500.0),
                job = job("j1", status = RepairJobStatus.Completed)
                    .copy(estimatedCostRupees = 9999.0),
            ),
        )
        val totals = computeEarningTotals(rows)
        assertEquals(1500.0, totals.paid, 0.0001)
    }

    private fun row(
        amount: Double,
        status: RepairJobStatus,
    ) = EarningsViewModel.EarningRow(
        bid = bid(id = "b-$status-$amount", jobId = "j-$status", amount = amount),
        job = job(id = "j-$status", status = status),
    )

    private fun bid(
        id: String,
        jobId: String = "j-$id",
        amount: Double = 1000.0,
    ) = RepairBid(
        id = id,
        repairJobId = jobId,
        engineerUserId = "eng-1",
        amountRupees = amount,
        etaHours = 4,
        note = null,
        status = RepairBidStatus.Accepted,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private fun job(
        id: String,
        status: RepairJobStatus = RepairJobStatus.Requested,
    ) = RepairJob(
        id = id,
        jobNumber = null,
        title = "Test job",
        issueDescription = "issue",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = false,
        engineerId = null,
        hospitalUserId = null,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )
}
