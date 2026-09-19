package com.equipseva.app.features.mybids

import com.equipseva.app.core.data.repair.RepairBidStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * Pins the My-bids tab set and the profitability distance format.
 */
class MyBidsTabsAndDistanceTest {

    @Test fun `every real bid status has a tab`() {
        // Critical pin. Withdrawn had no tab, no count and no other
        // surface, so a bid the engineer withdrew themselves simply
        // disappeared from the app — which reads as data loss rather
        // than as a completed action. Unknown is excluded: it is the
        // client's parse fallback for an unrecognised literal, and a
        // tab for it would advertise a decoding failure to the user.
        val missing = RepairBidStatus.entries
            .filter { it != RepairBidStatus.Unknown }
            .filter { it !in MY_BIDS_TAB_STATUSES }
        assertEquals(emptyList<RepairBidStatus>(), missing)
    }

    @Test fun `the unknown fallback gets no tab`() {
        assertTrue(RepairBidStatus.Unknown !in MY_BIDS_TAB_STATUSES)
    }

    @Test fun `pending leads the strip because it is the default filter`() {
        // The screen coerces a null filter to Pending, so a different
        // first tab would render as "Pending selected, Accepted first".
        assertEquals(RepairBidStatus.Pending, MY_BIDS_TAB_STATUSES.first())
    }

    @Test fun `empty-state copy works for every tab including Withdrawn`() {
        // The new tab must not land on blank or placeholder copy.
        for (status in MY_BIDS_TAB_STATUSES) {
            assertTrue(myBidsEmptyTitle(status).isNotBlank())
            assertTrue(myBidsEmptySubtitle(status).isNotBlank())
        }
        assertEquals("No withdrawn bids", myBidsEmptyTitle(RepairBidStatus.Withdrawn))
    }

    @Test fun `round trip distance shows one decimal`() {
        // The RPC hands over a raw Double which interpolated verbatim as
        // "12.345678 km round trip" — six decimals of GPS noise
        // presented as a cost input.
        assertEquals("12.3 km", roundTripDistanceLabel(12.345678))
        assertEquals("0.0 km", roundTripDistanceLabel(0.0))
        assertEquals("140.0 km", roundTripDistanceLabel(140.0))
    }

    @Test fun `round trip distance rounds rather than truncates`() {
        assertEquals("12.4 km", roundTripDistanceLabel(12.35))
    }

    @Test fun `round trip distance keeps a dot separator in a comma-decimal locale`() {
        // Locale pin: on a Hindi or German device the default formatter
        // renders "12,3 km", which reads as two values inside the
        // parenthesised phrase the label sits in.
        val original = Locale.getDefault()
        try {
            Locale.setDefault(Locale.GERMANY)
            assertEquals("12.3 km", roundTripDistanceLabel(12.345678))
        } finally {
            Locale.setDefault(original)
        }
    }
}
