package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Two AMC-detail readings that used to contradict the rest of the screen.
 */
class AmcDetailBannerAndVisitsTest {

    // ---- showAmcPausedBanner ------------------------------------------

    @Test fun `server-reported pause always wins`() {
        // The backend also pauses for reasons the client cannot see (admin
        // suspension), so this signal is authoritative on its own.
        assertTrue(showAmcPausedBanner(status = "paused", pausedByServer = true, poolBalance = 5000.0))
        assertTrue(showAmcPausedBanner(status = "active", pausedByServer = true, poolBalance = null))
    }

    @Test fun `an empty pool on an active contract is paused`() {
        assertTrue(showAmcPausedBanner(status = "active", pausedByServer = false, poolBalance = 0.0))
        assertTrue(showAmcPausedBanner(status = "active", pausedByServer = false, poolBalance = -10.0))
    }

    @Test fun `a failed balance fetch is not an empty pool`() {
        // Null means getPoolBalance FAILED (it is best-effort). Defaulting it
        // to zero put a red "paused" banner above a status pill still reading
        // Active on every network blip, and RefreshOnReturn repeated it.
        assertFalse(showAmcPausedBanner(status = "active", pausedByServer = false, poolBalance = null))
    }

    @Test fun `cancelled and expired contracts are not paused`() {
        // Their pool is empty by definition; "paused" implies a top-up would
        // resume them, and their own status pill already says otherwise.
        listOf("cancelled", "expired", "renewal_failed", "pending_payment").forEach { status ->
            assertFalse(
                "$status must not read as paused",
                showAmcPausedBanner(status = status, pausedByServer = false, poolBalance = 0.0),
            )
        }
    }

    @Test fun `a funded active contract shows no banner`() {
        assertFalse(showAmcPausedBanner(status = "active", pausedByServer = false, poolBalance = 12_000.0))
    }

    // ---- amcVisitsDoneThisYear ----------------------------------------

    @Test fun `a completed year reads as full, not zero`() {
        // The server counter is monotonic across years, so the 12th of 12
        // visits landed on a plain modulo of 0 — the one moment the quota is
        // actually finished.
        assertEquals(12, amcVisitsDoneThisYear(visitsDone = 12, visitsPerYear = 12))
        assertEquals(12, amcVisitsDoneThisYear(visitsDone = 24, visitsPerYear = 12))
    }

    @Test fun `part-way through a year counts from the year start`() {
        assertEquals(1, amcVisitsDoneThisYear(visitsDone = 13, visitsPerYear = 12))
        assertEquals(5, amcVisitsDoneThisYear(visitsDone = 5, visitsPerYear = 12))
    }

    @Test fun `a brand new contract reads zero`() {
        assertEquals(0, amcVisitsDoneThisYear(visitsDone = 0, visitsPerYear = 12))
    }

    @Test fun `an unknown yearly quota falls back to the raw count`() {
        assertEquals(7, amcVisitsDoneThisYear(visitsDone = 7, visitsPerYear = 0))
        assertEquals(7, amcVisitsDoneThisYear(visitsDone = 7, visitsPerYear = -1))
    }
}
