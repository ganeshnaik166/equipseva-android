package com.equipseva.app.features.mybids

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins MyBidsViewModel.UiState.visibleRows — the chip-row status filter
 * on the engineer's "My bids" screen. A regression here either shows
 * the engineer every bid regardless of the chip or hides everything,
 * both of which look like a stuck feed.
 */
class MyBidsUiStateTest {

    @Test fun `null filter returns the full row list in original order`() {
        val rows = listOf(
            row(bidId = "b1", status = RepairBidStatus.Pending),
            row(bidId = "b2", status = RepairBidStatus.Accepted),
            row(bidId = "b3", status = RepairBidStatus.Withdrawn),
        )
        val state = MyBidsViewModel.UiState(rows = rows, statusFilter = null)
        assertEquals(rows, state.visibleRows)
    }

    @Test fun `filter keeps only matching bids and preserves order`() {
        val pendingOne = row(bidId = "b1", status = RepairBidStatus.Pending)
        val accepted = row(bidId = "b2", status = RepairBidStatus.Accepted)
        val pendingTwo = row(bidId = "b3", status = RepairBidStatus.Pending)
        val state = MyBidsViewModel.UiState(
            rows = listOf(pendingOne, accepted, pendingTwo),
            statusFilter = RepairBidStatus.Pending,
        )
        assertEquals(listOf(pendingOne, pendingTwo), state.visibleRows)
    }

    @Test fun `filter with no matches returns empty list`() {
        val state = MyBidsViewModel.UiState(
            rows = listOf(row(status = RepairBidStatus.Pending)),
            statusFilter = RepairBidStatus.Accepted,
        )
        assertTrue(state.visibleRows.isEmpty())
    }

    @Test fun `unknown status filter pins Unknown-only bids`() {
        // RepairBidStatus.Unknown is the parser fallback for unrecognized
        // server values — the chip-row hides it but the filter should
        // still work when the screen exposes it as a debug option.
        val unknown = row(bidId = "b9", status = RepairBidStatus.Unknown)
        val pending = row(bidId = "b1", status = RepairBidStatus.Pending)
        val state = MyBidsViewModel.UiState(
            rows = listOf(unknown, pending),
            statusFilter = RepairBidStatus.Unknown,
        )
        assertEquals(listOf(unknown), state.visibleRows)
    }

    @Test fun `empty rows list yields empty visibleRows regardless of filter`() {
        val none = MyBidsViewModel.UiState(rows = emptyList(), statusFilter = null)
        assertTrue(none.visibleRows.isEmpty())
        val filtered = MyBidsViewModel.UiState(
            rows = emptyList(),
            statusFilter = RepairBidStatus.Accepted,
        )
        assertTrue(filtered.visibleRows.isEmpty())
    }

    @Test fun `null filter returns the same list instance (no needless copy)`() {
        // The branch returns `rows` directly when statusFilter is null —
        // pin that so a future refactor doesn't quietly box every emit
        // into a fresh list and tank scroll performance.
        val rows = listOf(row())
        val state = MyBidsViewModel.UiState(rows = rows, statusFilter = null)
        assertSame(rows, state.visibleRows)
    }

    @Test fun `default UiState reports loading with no rows and no error`() {
        // Mirrors the init { _state = MutableStateFlow(UiState()) } seed —
        // the engineer should see the loading skeleton, never a "no bids
        // yet" empty state, on first paint.
        val state = MyBidsViewModel.UiState()
        assertTrue(state.loading)
        assertTrue(state.rows.isEmpty())
        assertTrue(state.visibleRows.isEmpty())
        assertEquals(0, state.queuedBidCount)
        assertEquals(null, state.errorMessage)
        assertEquals(null, state.statusFilter)
    }

    private fun row(
        bidId: String = "b1",
        status: RepairBidStatus = RepairBidStatus.Pending,
        job: RepairJob? = null,
    ) = MyBidsViewModel.MyBidRow(
        bid = bid(id = bidId, status = status),
        job = job,
    )

    private fun bid(
        id: String,
        status: RepairBidStatus,
    ) = RepairBid(
        id = id,
        repairJobId = "j-$id",
        engineerUserId = "eng-1",
        amountRupees = 1000.0,
        etaHours = 4,
        note = null,
        status = status,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    @Suppress("unused")
    private fun job(
        id: String = "j1",
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
