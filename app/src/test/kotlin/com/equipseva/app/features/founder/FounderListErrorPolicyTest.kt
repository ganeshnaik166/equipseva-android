package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins how the founder queue screens surface a load failure.
 *
 * Critical regression target: the AMC-expiring, paused-AMC,
 * inactive-engineer and integrity queues branched on `error != null` before
 * looking at their rows, so one failed pull-to-refresh replaced a list the
 * founder was working through with "Couldn't load". Their siblings (KYC,
 * payments, reports, cash-flag history) only do that on an empty list.
 *
 * The two helpers are deliberately complementary: exactly one of them fires
 * for any given state, so the founder never gets a banner and a full-screen
 * error for the same failure.
 */
class FounderListErrorPolicyTest {

    @Test fun `error with no rows takes over the screen`() {
        assertTrue(founderListShowsErrorState("Network unreachable", rowCount = 0))
    }

    @Test fun `error with rows loaded does not take over the screen`() {
        // The regression target.
        assertFalse(founderListShowsErrorState("Network unreachable", rowCount = 12))
    }

    @Test fun `no error never takes over the screen`() {
        assertFalse(founderListShowsErrorState(null, rowCount = 0))
        assertFalse(founderListShowsErrorState(null, rowCount = 12))
    }

    @Test fun `refresh banner carries the message only when rows survive`() {
        assertEquals("Network unreachable", founderListRefreshBanner("Network unreachable", 12))
        assertNull(founderListRefreshBanner("Network unreachable", 0))
        assertNull(founderListRefreshBanner(null, 12))
        assertNull(founderListRefreshBanner(null, 0))
    }

    @Test fun `the two surfaces are mutually exclusive across every state`() {
        listOf(null, "boom").forEach { error ->
            listOf(0, 1, 50).forEach { rows ->
                val takesOver = founderListShowsErrorState(error, rows)
                val banners = founderListRefreshBanner(error, rows) != null
                assertFalse(
                    "error=$error rows=$rows showed both surfaces",
                    takesOver && banners,
                )
            }
        }
    }

    @Test fun `a real error is always surfaced somewhere`() {
        listOf(0, 1, 50).forEach { rows ->
            val takesOver = founderListShowsErrorState("boom", rows)
            val banners = founderListRefreshBanner("boom", rows) != null
            assertTrue("rows=$rows swallowed the error", takesOver || banners)
        }
    }
}
