package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

class FounderHeroJobsValueTest {

    @Test fun `non-null value passes through verbatim`() {
        assertEquals("42", founderHeroJobsValue(42))
    }

    @Test fun `null jobsToday defaults to 0 (stable hero silhouette)`() {
        // Critical pin — null conflated with actual zero. Pin documents
        // the deliberate UX trade-off: hero needs stable visual.
        assertEquals("0", founderHeroJobsValue(null))
    }

    @Test fun `actual zero also reads 0`() {
        // Confirms the null and zero paths render the same — a refactor
        // that introduced a "—" placeholder for null only would surface
        // here.
        assertEquals("0", founderHeroJobsValue(0))
        assertEquals(founderHeroJobsValue(0), founderHeroJobsValue(null))
    }

    @Test fun `large value interpolates as decimal string (no grouping)`() {
        // Pin no thousands grouping — hero is compact and a single
        // line; the "Jobs posted today" label sits above so context
        // is already clear.
        assertEquals("1234", founderHeroJobsValue(1234))
    }

    @Test fun `negative value renders verbatim (defensive)`() {
        // Defensive — server shouldn't send negative, but pin.
        assertEquals("-1", founderHeroJobsValue(-1))
    }
}
