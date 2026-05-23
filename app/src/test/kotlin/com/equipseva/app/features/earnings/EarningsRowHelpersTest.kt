package com.equipseva.app.features.earnings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three helpers behind the engineer's earnings transaction
 * row + self-rank card.
 */
class EarningsRowHelpersTest {

    // ---- transactionRowTimeLine --------------------------------------

    @Test fun `paid with relative label reads Paid Nd ago`() {
        assertEquals(
            "Paid 2d ago",
            transactionRowTimeLine(paid = true, relativeAgoLabel = "2d", statusDisplayName = "Completed"),
        )
    }

    @Test fun `pending with relative label reads Quoted Nd ago`() {
        // Pin the Paid/Quoted verb split — a refactor that always
        // said "Paid" would mislead on pending bids.
        assertEquals(
            "Quoted 3h ago",
            transactionRowTimeLine(paid = false, relativeAgoLabel = "3h", statusDisplayName = "Awaiting"),
        )
    }

    @Test fun `null relative falls back to status display name`() {
        assertEquals(
            "Awaiting hospital",
            transactionRowTimeLine(paid = false, relativeAgoLabel = null, statusDisplayName = "Awaiting hospital"),
        )
    }

    @Test fun `null relative + null status returns empty (row stays mounted but invisible)`() {
        assertEquals(
            "",
            transactionRowTimeLine(paid = false, relativeAgoLabel = null, statusDisplayName = null),
        )
    }

    @Test fun `paid takes priority — relative wins over status`() {
        // Pin gate ordering — relative > status when both present.
        assertEquals(
            "Paid 1d ago",
            transactionRowTimeLine(paid = true, relativeAgoLabel = "1d", statusDisplayName = "Completed"),
        )
    }

    // ---- transactionRowDisplayAmount ---------------------------------

    @Test fun `paid row uses payout when populated`() {
        // Critical pin — post-commission payout is the truth on paid.
        assertEquals(
            9000.0,
            transactionRowDisplayAmount(
                paid = true,
                engineerPayoutRupees = 9000.0,
                bidAmountRupees = 10_000.0,
            ),
            0.0,
        )
    }

    @Test fun `paid row falls back to bid amount when payout is null`() {
        // Legacy pre-trigger rows OR the brief window between
        // status=completed and the payout-trigger write.
        assertEquals(
            10_000.0,
            transactionRowDisplayAmount(
                paid = true,
                engineerPayoutRupees = null,
                bidAmountRupees = 10_000.0,
            ),
            0.0,
        )
    }

    @Test fun `pending row uses bid amount even when payout populated`() {
        // Critical pin — never tease post-commission payout before
        // resolution. The engineer bid X, expects to see X.
        assertEquals(
            10_000.0,
            transactionRowDisplayAmount(
                paid = false,
                engineerPayoutRupees = 9000.0,
                bidAmountRupees = 10_000.0,
            ),
            0.0,
        )
    }

    @Test fun `pending row with null payout still uses bid amount`() {
        assertEquals(
            5000.0,
            transactionRowDisplayAmount(
                paid = false,
                engineerPayoutRupees = null,
                bidAmountRupees = 5000.0,
            ),
            0.0,
        )
    }

    // ---- selfRankSubtitle --------------------------------------------

    @Test fun `singular job for 1 completed`() {
        // Critical pin — never "1 jobs".
        val out = selfRankSubtitle(1L, 10_000.0)
        assertTrue(out.startsWith("1 job ·"))
    }

    @Test fun `plural jobs for 2 completed`() {
        val out = selfRankSubtitle(2L, 20_000.0)
        assertTrue(out.startsWith("2 jobs ·"))
    }

    @Test fun `plural jobs for 0 completed (defensive)`() {
        // Pin the 0 branch — reads "0 jobs", not "0 job".
        val out = selfRankSubtitle(0L, 0.0)
        assertTrue(out.startsWith("0 jobs ·"))
    }

    @Test fun `large count interpolates with plural`() {
        val out = selfRankSubtitle(42L, 100_000.0)
        assertTrue(out.startsWith("42 jobs ·"))
    }

    @Test fun `middle dot is U+00B7 not ASCII period`() {
        val out = selfRankSubtitle(1L, 1.0)
        assertTrue(out.contains('·'))
    }
}
