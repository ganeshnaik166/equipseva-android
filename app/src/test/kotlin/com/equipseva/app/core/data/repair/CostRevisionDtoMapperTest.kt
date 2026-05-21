package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [CostRevisionDto] → [CostRevision] mapping + the
 * [CostRevisionStatus] enum's case-insensitive `fromKey`. The
 * cost-revision banner / decision sheet on RepairJobDetail is driven
 * by the resulting domain object; a regression that mis-classified
 * status would leave engineers without a way to surface "Approved" or
 * "Rejected" outcomes.
 */
class CostRevisionDtoMapperTest {

    private fun dto(
        id: String = "cr1",
        status: String = "proposed",
        createdAtIso: String? = null,
    ) = CostRevisionDto(
        id = id,
        repairJobId = "j1",
        engineerUserId = "u1",
        originalAmountRupees = 1000.0,
        revisedAmountRupees = 1500.0,
        reason = "Replacing damaged probe head",
        status = status,
        createdAtIso = createdAtIso,
    )

    @Test fun `populated dto round-trips fields and parses ISO`() {
        val out = dto(createdAtIso = "2026-05-21T10:00:00Z").toDomain()
        assertEquals("cr1", out.id)
        assertEquals("j1", out.repairJobId)
        assertEquals("u1", out.engineerUserId)
        assertEquals(1000.0, out.originalAmountRupees, 0.001)
        assertEquals(1500.0, out.revisedAmountRupees, 0.001)
        assertEquals("Replacing damaged probe head", out.reason)
        assertEquals(CostRevisionStatus.Proposed, out.status)
        assertEquals("2026-05-21T10:00:00Z", out.createdAt?.toString())
    }

    @Test fun `null createdAt iso maps to null instant`() {
        assertNull(dto().toDomain().createdAt)
    }

    @Test fun `malformed createdAt iso folds to null without crash`() {
        // The detail screen's relative-time chip can't render an
        // invalid instant; folding to null leaves the chip hidden
        // rather than crashing the row.
        assertNull(dto(createdAtIso = "garbage").toDomain().createdAt)
    }

    @Test fun `status maps each known key to enum entry`() {
        assertEquals(CostRevisionStatus.Proposed, dto(status = "proposed").toDomain().status)
        assertEquals(CostRevisionStatus.Approved, dto(status = "approved").toDomain().status)
        assertEquals(CostRevisionStatus.Rejected, dto(status = "rejected").toDomain().status)
        assertEquals(CostRevisionStatus.Expired, dto(status = "expired").toDomain().status)
    }

    @Test fun `status mapping is case-insensitive`() {
        // The server-side enum is lowercase but the fromKey helper
        // tolerates upper-case for safety — pin so the tolerance
        // isn't accidentally tightened away.
        assertEquals(CostRevisionStatus.Approved, CostRevisionStatus.fromKey("APPROVED"))
        assertEquals(CostRevisionStatus.Approved, CostRevisionStatus.fromKey("Approved"))
    }

    @Test fun `unknown status key falls back to Proposed (initial state)`() {
        // Proposed is the safest default — the banner / decision
        // sheet will render with proposal-time copy and the engineer
        // / hospital still has the action surface to resolve.
        assertEquals(CostRevisionStatus.Proposed, CostRevisionStatus.fromKey("future_state"))
        assertEquals(CostRevisionStatus.Proposed, CostRevisionStatus.fromKey(null))
    }
}
