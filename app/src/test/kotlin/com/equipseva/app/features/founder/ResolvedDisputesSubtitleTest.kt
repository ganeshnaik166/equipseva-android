package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ResolvedDisputesSubtitleTest {

    @Test fun `non-empty list reads N in last 30 days`() {
        assertEquals(
            "5 in last 30 days",
            resolvedDisputesSubtitle(5),
        )
    }

    @Test fun `empty list returns null`() {
        assertNull(resolvedDisputesSubtitle(0))
    }

    @Test fun `1 row reads 1 in last 30 days (noun-less)`() {
        // Critical pin — no noun. A refactor to "N disputes in last 30
        // days" would surface "1 disputes" on the singular case. Screen
        // title already supplies the noun.
        assertEquals(
            "1 in last 30 days",
            resolvedDisputesSubtitle(1),
        )
    }

    @Test fun `30 days suffix preserved verbatim`() {
        val out = resolvedDisputesSubtitle(1)
        assertTrue(out!!.endsWith("in last 30 days"))
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals(
            "42 in last 30 days",
            resolvedDisputesSubtitle(42),
        )
    }
}
