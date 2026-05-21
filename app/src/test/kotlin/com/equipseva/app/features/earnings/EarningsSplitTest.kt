package com.equipseva.app.features.earnings

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the earnings paid / pending projection. Three regions worth
 * defending:
 *
 *   1) Rows with no resolved job (server-side delete, RLS hide, row
 *      dropped) are filtered out — they used to inflate the
 *      pending total under "Repair job" placeholder rows.
 *   2) Paid total uses `job.engineerPayoutRupees` (post-commission)
 *      when present, falling back to the bid amount only on legacy
 *      rows pre-dating the PR-D36 commission trigger.
 *   3) Pending total stays on the bid amount (estimate) since the
 *      commission split hasn't been computed yet.
 */
class EarningsSplitTest {

    private fun bid(
        id: String,
        amountRupees: Double = 2500.0,
        status: RepairBidStatus = RepairBidStatus.Accepted,
    ): RepairBid = RepairBid(
        id = id,
        repairJobId = "j-$id",
        engineerUserId = "u-1",
        amountRupees = amountRupees,
        etaHours = null,
        note = null,
        status = status,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private fun job(
        id: String,
        status: RepairJobStatus,
        engineerPayoutRupees: Double? = null,
    ): RepairJob = RepairJob(
        id = id,
        jobNumber = null,
        title = "Repair",
        issueDescription = "",
        equipmentCategory = RepairEquipmentCategory.Other,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Unknown,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = true,
        engineerId = "e-1",
        hospitalUserId = "h-1",
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
        engineerPayoutRupees = engineerPayoutRupees,
    )

    @Test fun `empty rows yield zero totals and empty resolved list`() {
        val out = computeEarningsSplit(emptyList())
        assertEquals(0.0, out.paidTotal, 0.001)
        assertEquals(0.0, out.pendingTotal, 0.001)
        assertEquals(emptyList<EarningsViewModel.EarningRow>(), out.resolvedRows)
    }

    @Test fun `null-job rows are filtered from resolvedRows AND from both totals`() {
        // Drop bids whose job vanished — they previously inflated
        // pendingTotal as "Repair job" placeholders.
        val rows = listOf(
            EarningsViewModel.EarningRow(bid = bid("a"), job = null),
            EarningsViewModel.EarningRow(bid = bid("b"), job = null),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(0.0, out.paidTotal, 0.001)
        assertEquals(0.0, out.pendingTotal, 0.001)
        assertEquals(emptyList<EarningsViewModel.EarningRow>(), out.resolvedRows)
    }

    @Test fun `completed jobs with payout use engineerPayoutRupees, not bid amount`() {
        // PR-D36 — paid total reflects the post-commission payout
        // (85% of bid in this example). Pin so a regression to "sum
        // bid amount" wouldn't silently over-state earnings.
        val rows = listOf(
            EarningsViewModel.EarningRow(
                bid = bid("a", amountRupees = 1000.0),
                job = job("a", RepairJobStatus.Completed, engineerPayoutRupees = 850.0),
            ),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(850.0, out.paidTotal, 0.001)
    }

    @Test fun `completed jobs WITHOUT payout fall back to bid amount (legacy rows)`() {
        // Legacy rows that completed before the commission trigger
        // shipped have engineerPayoutRupees=null. Sum bid amount so
        // the historical earnings hero stays correct.
        val rows = listOf(
            EarningsViewModel.EarningRow(
                bid = bid("a", amountRupees = 1000.0),
                job = job("a", RepairJobStatus.Completed, engineerPayoutRupees = null),
            ),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(1000.0, out.paidTotal, 0.001)
    }

    @Test fun `non-completed jobs sum bid amount into pendingTotal`() {
        // In-progress / assigned / en-route → pending. Use bid
        // amount (estimate); commission hasn't been computed yet.
        val rows = listOf(
            EarningsViewModel.EarningRow(
                bid = bid("a", amountRupees = 2000.0),
                job = job("a", RepairJobStatus.Assigned),
            ),
            EarningsViewModel.EarningRow(
                bid = bid("b", amountRupees = 3500.0),
                job = job("b", RepairJobStatus.InProgress),
            ),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(0.0, out.paidTotal, 0.001)
        assertEquals(5500.0, out.pendingTotal, 0.001)
    }

    @Test fun `mixed completed and in-progress rows split correctly`() {
        val rows = listOf(
            // Paid — completed with explicit payout.
            EarningsViewModel.EarningRow(
                bid = bid("a", amountRupees = 1000.0),
                job = job("a", RepairJobStatus.Completed, engineerPayoutRupees = 850.0),
            ),
            // Paid — completed legacy (no payout column).
            EarningsViewModel.EarningRow(
                bid = bid("b", amountRupees = 1500.0),
                job = job("b", RepairJobStatus.Completed, engineerPayoutRupees = null),
            ),
            // Pending — in progress.
            EarningsViewModel.EarningRow(
                bid = bid("c", amountRupees = 2000.0),
                job = job("c", RepairJobStatus.InProgress),
            ),
            // Filtered out — no job.
            EarningsViewModel.EarningRow(bid = bid("d", amountRupees = 999.0), job = null),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(850.0 + 1500.0, out.paidTotal, 0.001)
        assertEquals(2000.0, out.pendingTotal, 0.001)
        assertEquals(3, out.resolvedRows.size)
        assertEquals(
            listOf("a", "b", "c"),
            out.resolvedRows.map { it.bid.id },
        )
    }

    @Test fun `cancelled jobs go into pendingTotal (not paid)`() {
        // Cancelled is neither Completed nor null-job; the engineer
        // is still owed the bid amount until the cancellation flow
        // resolves the payment. Pin so a future refactor that "drops
        // cancelled" doesn't silently zero out earnings.
        val rows = listOf(
            EarningsViewModel.EarningRow(
                bid = bid("a", amountRupees = 2000.0),
                job = job("a", RepairJobStatus.Cancelled),
            ),
        )
        val out = computeEarningsSplit(rows)
        assertEquals(0.0, out.paidTotal, 0.001)
        assertEquals(2000.0, out.pendingTotal, 0.001)
    }
}
