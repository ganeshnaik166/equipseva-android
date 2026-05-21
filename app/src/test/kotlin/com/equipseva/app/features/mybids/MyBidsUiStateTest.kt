package com.equipseva.app.features.mybids

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * Pins the My-Bids status-filter projection. `statusFilter == null`
 * is the unfiltered "all" tab and must short-circuit to the source
 * list identity (avoids re-allocating the same content every chip
 * tap, keeps the LazyColumn stable).
 */
class MyBidsUiStateTest {

    private fun bid(id: String, status: RepairBidStatus): RepairBid = RepairBid(
        id = id,
        repairJobId = "j-$id",
        engineerUserId = "u-$id",
        amountRupees = 2500.0,
        etaHours = 2,
        note = null,
        status = status,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private val sampleRows = listOf(
        MyBidsViewModel.MyBidRow(bid("b1", RepairBidStatus.Pending), job = null),
        MyBidsViewModel.MyBidRow(bid("b2", RepairBidStatus.Accepted), job = null),
        MyBidsViewModel.MyBidRow(bid("b3", RepairBidStatus.Rejected), job = null),
        MyBidsViewModel.MyBidRow(bid("b4", RepairBidStatus.Withdrawn), job = null),
    )

    @Test fun `null filter returns the source list by identity (no realloc)`() {
        val state = MyBidsViewModel.UiState(loading = false, rows = sampleRows, statusFilter = null)
        // Identity not equality — the filter chip toggles can fire
        // many times per second; re-allocating a new list on every
        // tap would churn the LazyColumn's keys.
        assertSame(sampleRows, state.visibleRows)
    }

    @Test fun `Pending filter shows only pending bids`() {
        val state = MyBidsViewModel.UiState(
            loading = false,
            rows = sampleRows,
            statusFilter = RepairBidStatus.Pending,
        )
        assertEquals(listOf("b1"), state.visibleRows.map { it.bid.id })
    }

    @Test fun `Accepted filter shows only accepted bids`() {
        val state = MyBidsViewModel.UiState(
            loading = false,
            rows = sampleRows,
            statusFilter = RepairBidStatus.Accepted,
        )
        assertEquals(listOf("b2"), state.visibleRows.map { it.bid.id })
    }

    @Test fun `filter with no matching rows yields empty list (not null)`() {
        val state = MyBidsViewModel.UiState(
            loading = false,
            rows = listOf(sampleRows[0]),
            statusFilter = RepairBidStatus.Rejected,
        )
        assertEquals(emptyList<MyBidsViewModel.MyBidRow>(), state.visibleRows)
    }
}
