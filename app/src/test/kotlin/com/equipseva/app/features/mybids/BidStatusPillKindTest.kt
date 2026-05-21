package com.equipseva.app.features.mybids

import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the MyBids list bid-card pill colour mapping. The pill colour
 * is load-bearing — Accepted (green Success) and Rejected (red Danger)
 * are the user's at-a-glance recovery signal. Pending and Unknown
 * share Info so an in-flight bid + a legacy unmapped row both read
 * as "still resolving" rather than as success/failure.
 */
class BidStatusPillKindTest {

    @Test fun `Accepted maps to Success (green)`() {
        assertEquals(PillKind.Success, bidStatusPillKind(RepairBidStatus.Accepted))
    }

    @Test fun `Rejected maps to Danger (red)`() {
        assertEquals(PillKind.Danger, bidStatusPillKind(RepairBidStatus.Rejected))
    }

    @Test fun `Withdrawn maps to Neutral (de-emphasised)`() {
        // Withdrawn was the engineer's own choice, not a server-side
        // outcome — pin so it doesn't drift to Danger and panic the
        // engineer reviewing their history.
        assertEquals(PillKind.Neutral, bidStatusPillKind(RepairBidStatus.Withdrawn))
    }

    @Test fun `Pending maps to Info (in-flight)`() {
        assertEquals(PillKind.Info, bidStatusPillKind(RepairBidStatus.Pending))
    }

    @Test fun `Unknown legacy row maps to Info (no false success or failure)`() {
        // Forward-compat: an unmapped server-side status that fell
        // through to Unknown via fromKey must NOT read as
        // Success/Danger — pin so the conservative Info default
        // stays.
        assertEquals(PillKind.Info, bidStatusPillKind(RepairBidStatus.Unknown))
    }
}
