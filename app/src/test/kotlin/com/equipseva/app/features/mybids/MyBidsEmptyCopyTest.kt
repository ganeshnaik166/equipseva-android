package com.equipseva.app.features.mybids

import com.equipseva.app.core.data.repair.RepairBidStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MyBidsEmptyCopyTest {

    // ---- myBidsEmptyTitle --------------------------------------------

    @Test fun `pending filter title lowercases the noun`() {
        // Pin lowercase — flows as noun inside "No X bids" sentence.
        assertEquals("No pending bids", myBidsEmptyTitle(RepairBidStatus.Pending))
    }

    @Test fun `accepted filter title lowercases the noun`() {
        assertEquals("No accepted bids", myBidsEmptyTitle(RepairBidStatus.Accepted))
    }

    @Test fun `rejected filter title lowercases the noun`() {
        assertEquals("No rejected bids", myBidsEmptyTitle(RepairBidStatus.Rejected))
    }

    @Test fun `withdrawn filter title lowercases the noun`() {
        assertEquals("No withdrawn bids", myBidsEmptyTitle(RepairBidStatus.Withdrawn))
    }

    // ---- myBidsEmptySubtitle -----------------------------------------

    @Test fun `pending filter shows action-prompt with hour expectation`() {
        // Critical pin — "within an hour" trust signal.
        val out = myBidsEmptySubtitle(RepairBidStatus.Pending)
        assertTrue(out.contains("Place a bid"))
        assertTrue(out.contains("within an hour"))
    }

    @Test fun `non-pending filters show generic tab-switch nudge`() {
        // Pin — single shared copy for non-pending tabs.
        assertEquals(
            "Switch tabs to see other bid states.",
            myBidsEmptySubtitle(RepairBidStatus.Accepted),
        )
        assertEquals(
            "Switch tabs to see other bid states.",
            myBidsEmptySubtitle(RepairBidStatus.Rejected),
        )
        assertEquals(
            "Switch tabs to see other bid states.",
            myBidsEmptySubtitle(RepairBidStatus.Withdrawn),
        )
    }

    // ---- myBidsEmptyCtaLabel -----------------------------------------

    @Test fun `pending filter has Browse open jobs CTA`() {
        assertEquals(
            "Browse open jobs",
            myBidsEmptyCtaLabel(RepairBidStatus.Pending),
        )
    }

    @Test fun `non-pending filters have null CTA`() {
        // Critical pin — no CTA on filter tabs to avoid leading user
        // away from the queue they're looking at.
        assertNull(myBidsEmptyCtaLabel(RepairBidStatus.Accepted))
        assertNull(myBidsEmptyCtaLabel(RepairBidStatus.Rejected))
        assertNull(myBidsEmptyCtaLabel(RepairBidStatus.Withdrawn))
    }
}
