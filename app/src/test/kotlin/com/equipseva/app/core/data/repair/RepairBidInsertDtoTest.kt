package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * The "place bid" flow drops two require() blocks (amount range + ETA range)
 * before building the insert DTO. The UI surfaces a friendlier validation
 * pass first, but these are the load-bearing server-shape guards — pin both
 * branches so a refactor doesn't silently widen them. Also pins the blank-
 * note collapse: an engineer who hits "submit" with whitespace in the note
 * field should not persist `"   "` (the read-side toDomain already collapses
 * it, but writing it wastes a column slot).
 */
class RepairBidInsertDtoTest {

    @Test fun `valid inputs produce a passthrough insert DTO with default status`() {
        val dto = buildRepairBidInsertDto(
            jobId = "job-1",
            engineerUserId = "eng-1",
            amountRupees = 2500.0,
            etaHours = 6,
            note = "Will bring spares",
        )

        assertEquals("job-1", dto.repairJobId)
        assertEquals("eng-1", dto.engineerUserId)
        assertEquals(2500.0, dto.amountRupees, 0.0)
        assertEquals(6, dto.etaHours)
        assertEquals("Will bring spares", dto.note)
        // status default is hardcoded on the DTO; pin so a refactor that
        // routes through a status enum stays "pending".
        assertEquals("pending", dto.status)
    }

    @Test fun `null ETA and null note pass through`() {
        val dto = buildRepairBidInsertDto(
            jobId = "job-1",
            engineerUserId = "eng-1",
            amountRupees = 1.0,
            etaHours = null,
            note = null,
        )
        assertNull(dto.etaHours)
        assertNull(dto.note)
    }

    @Test fun `blank note collapses to null`() {
        val dto = buildRepairBidInsertDto(
            jobId = "job-1",
            engineerUserId = "eng-1",
            amountRupees = 1.0,
            etaHours = null,
            note = "   ",
        )
        assertNull(dto.note)
    }

    @Test fun `bid amount exactly at the inclusive bounds is accepted`() {
        // ₹1 and ₹1 crore are the explicit edges; this also catches a future
        // refactor that flips the range to half-open by mistake.
        val low = buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = null, note = null)
        val high = buildRepairBidInsertDto("j", "e", amountRupees = 10_000_000.0, etaHours = null, note = null)
        assertEquals(1.0, low.amountRupees, 0.0)
        assertEquals(10_000_000.0, high.amountRupees, 0.0)
    }

    @Test fun `bid amount below 1 rupee throws`() {
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = 0.0, etaHours = null, note = null)
        }
    }

    @Test fun `bid amount above 1 crore throws`() {
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = 10_000_001.0, etaHours = null, note = null)
        }
    }

    @Test fun `non-finite bid amount throws`() {
        // NaN and +/-Infinity satisfy the numeric range check on the JVM by
        // accident (NaN comparisons return false → trips the require), but
        // wire-format-wise they would corrupt the row. The isFinite() guard
        // is the one that catches this — pin all three forms.
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = Double.NaN, etaHours = null, note = null)
        }
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = Double.POSITIVE_INFINITY, etaHours = null, note = null)
        }
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = Double.NEGATIVE_INFINITY, etaHours = null, note = null)
        }
    }

    @Test fun `ETA exactly at the inclusive bounds is accepted`() {
        val low = buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = 1, note = null)
        val high = buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = 720, note = null)
        assertEquals(1, low.etaHours)
        assertEquals(720, high.etaHours)
    }

    @Test fun `ETA of zero or negative throws`() {
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = 0, note = null)
        }
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = -1, note = null)
        }
    }

    @Test fun `ETA above 720 hours throws`() {
        // 720 hours = 30 days. Anything longer than a month sitting in
        // "pending" is almost certainly a stale bid; we hard-cap.
        assertThrows(IllegalArgumentException::class.java) {
            buildRepairBidInsertDto("j", "e", amountRupees = 1.0, etaHours = 721, note = null)
        }
    }
}
