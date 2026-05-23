package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ExpiringAmcsSubtitleTest {

    @Test fun `non-empty list shows count contracts in next 30 days`() {
        assertEquals(
            "5 contracts in next 30 days",
            expiringAmcsSubtitle(5),
        )
    }

    @Test fun `empty list returns null`() {
        assertNull(expiringAmcsSubtitle(0))
    }

    @Test fun `30 days suffix is the literal constant`() {
        // Critical cross-surface invariant — the 30d window matches
        // server-side notify_expiring_amc_contracts cutoff AND the
        // dashboard KPI tile AND the hospital-side countdown. Pin
        // so a drift to 14d or 7d would silently desync the cohort.
        val out = expiringAmcsSubtitle(1)
        assertTrue(out!!.endsWith(" in next 30 days"))
    }

    @Test fun `1 row reads 1 contracts plural (documented current behaviour)`() {
        // Pin current behaviour — plural-blind. A "1 contracts" surface
        // is technically wrong but pinning it documents the state; a
        // future fix should be deliberate, not a slip.
        assertEquals(
            "1 contracts in next 30 days",
            expiringAmcsSubtitle(1),
        )
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals(
            "100 contracts in next 30 days",
            expiringAmcsSubtitle(100),
        )
    }
}
