package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the bid-insert payload composition + the three require() gates
 * (amount range, ETA range, note truncation). Each gate matches a
 * server-side CHECK so a slip-up here surfaces locally as
 * IllegalArgumentException rather than burning a network round-trip
 * and seeing a 23514 from Postgrest.
 */
class BuildRepairBidInsertTest {

    private fun build(
        amount: Double = 2500.0,
        etaHours: Int? = 4,
        note: String? = null,
    ) = buildRepairBidInsert(
        jobId = "j-1",
        engineerUserId = "u-1",
        amountRupees = amount,
        etaHours = etaHours,
        note = note,
    )

    @Test fun `happy path produces the wire DTO`() {
        val dto = build()
        assertEquals("j-1", dto.repairJobId)
        assertEquals("u-1", dto.engineerUserId)
        assertEquals(2500.0, dto.amountRupees, 0.001)
        assertEquals(4, dto.etaHours)
        assertNull(dto.note)
    }

    // ---- amount range gate ----

    @Test(expected = IllegalArgumentException::class)
    fun `zero amount throws (below floor)`() {
        build(amount = 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative amount throws`() {
        build(amount = -100.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `amount above 1 crore throws (above ceiling)`() {
        build(amount = MAX_BID_RUPEES + 1.0)
    }

    @Test fun `amount at floor and ceiling is accepted`() {
        // Pin the inclusive bounds — pin so a future >= vs > switch
        // is reviewed.
        assertEquals(1.0, build(amount = 1.0).amountRupees, 0.001)
        assertEquals(MAX_BID_RUPEES, build(amount = MAX_BID_RUPEES).amountRupees, 0.001)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `non-finite amount throws (NaN)`() {
        build(amount = Double.NaN)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `non-finite amount throws (Infinity)`() {
        build(amount = Double.POSITIVE_INFINITY)
    }

    // ---- ETA range gate ----

    @Test fun `null ETA is accepted (caller can omit ETA on a quick bid)`() {
        assertNull(build(etaHours = null).etaHours)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `zero ETA throws (below floor)`() {
        build(etaHours = 0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `ETA above 30 days throws (above ceiling)`() {
        build(etaHours = MAX_ETA_HOURS + 1)
    }

    @Test fun `ETA at floor and ceiling is accepted`() {
        assertEquals(1, build(etaHours = 1).etaHours)
        assertEquals(MAX_ETA_HOURS, build(etaHours = MAX_ETA_HOURS).etaHours)
    }

    // ---- note semantics ----

    @Test fun `null note passes through as null`() {
        assertNull(build(note = null).note)
    }

    @Test fun `blank note folds to null`() {
        // Empty-string / whitespace note shouldn't render an empty
        // bubble on the bid card — fold to null.
        assertNull(build(note = "  ").note)
        assertNull(build(note = "").note)
    }

    @Test fun `note longer than 1000 chars is truncated to the server cap`() {
        val long = "x".repeat(1500)
        val dto = build(note = long)
        assertEquals(1000, dto.note?.length)
    }

    @Test fun `note at exactly 1000 chars is preserved (server cap boundary)`() {
        val cap = "y".repeat(1000)
        assertEquals(1000, build(note = cap).note?.length)
    }

    @Test fun `non-blank note under cap passes through verbatim`() {
        val text = "Bringing a spare bulb and re-cal kit; ETA 3h."
        assertEquals(text, build(note = text).note)
    }

    // ---- constants ----

    @Test fun `MAX_BID_RUPEES is 1 crore (server CHECK alignment)`() {
        assertEquals(10_000_000.0, MAX_BID_RUPEES, 0.0)
    }

    @Test fun `MAX_ETA_HOURS is 720 hours (30 days)`() {
        assertEquals(720, MAX_ETA_HOURS)
    }
}
