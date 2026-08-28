package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression guard for the AMC-visit-in-repair-screens bug class (r1482/r1483).
 *
 * AMC maintenance visits reuse the RepairJobDetail screen but are created in
 * Requested status PRE-ASSIGNED to the contract's engineer (engineerId != null)
 * and are never bid on. So both the "No bids yet · raise your budget" banner and
 * the hospital "Bids / No bids yet" section must be suppressed for them, while
 * still showing for genuine open marketplace jobs. These pins fail if a future
 * edit drops the `engineerId == null` clause from either gate.
 */
class AmcJobBidUiGateTest {

    // ---- shouldShowUnmatchedJobBanner ---------------------------------------

    @Test fun `banner shows for an open, unassigned, aged job with no bids`() {
        assertTrue(
            shouldShowUnmatchedJobBanner(
                isHospital = true,
                status = RepairJobStatus.Requested,
                engineerId = null,
                hasBids = false,
                daysOld = 7L,
            ),
        )
    }

    @Test fun `banner hidden for an AMC pre-assigned job (engineerId set)`() {
        assertFalse(
            shouldShowUnmatchedJobBanner(
                isHospital = true,
                status = RepairJobStatus.Requested,
                engineerId = "eng-1",
                hasBids = false,
                daysOld = 30L,
            ),
        )
    }

    @Test fun `banner hidden before the 7-day threshold`() {
        assertFalse(shouldShowUnmatchedJobBanner(true, RepairJobStatus.Requested, null, false, 6L))
    }

    @Test fun `banner hidden once bids arrive`() {
        assertFalse(shouldShowUnmatchedJobBanner(true, RepairJobStatus.Requested, null, true, 30L))
    }

    @Test fun `banner hidden for a non-hospital viewer`() {
        assertFalse(shouldShowUnmatchedJobBanner(false, RepairJobStatus.Requested, null, false, 30L))
    }

    @Test fun `banner hidden once the job leaves Requested`() {
        assertFalse(shouldShowUnmatchedJobBanner(true, RepairJobStatus.Assigned, null, false, 30L))
    }

    // ---- shouldShowBidsSection ----------------------------------------------

    @Test fun `bids section shows for an open, unassigned Requested job`() {
        assertTrue(shouldShowBidsSection(true, RepairJobStatus.Requested, null))
    }

    @Test fun `bids section hidden for an AMC pre-assigned job`() {
        assertFalse(shouldShowBidsSection(true, RepairJobStatus.Requested, "eng-1"))
    }

    @Test fun `bids section hidden for a non-hospital viewer`() {
        assertFalse(shouldShowBidsSection(false, RepairJobStatus.Requested, null))
    }

    @Test fun `bids section hidden once the job leaves Requested`() {
        assertFalse(shouldShowBidsSection(true, RepairJobStatus.Assigned, null))
    }
}
