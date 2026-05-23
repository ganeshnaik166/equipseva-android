package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InactiveEngineersSubtitleTest {

    @Test fun `non-empty list shows count verified plus 0 jobs in 30d`() {
        assertEquals(
            "5 verified · 0 jobs in 30d",
            inactiveEngineersSubtitle(5),
        )
    }

    @Test fun `empty list returns null (top bar stays clean on cold-load)`() {
        // Critical pin — null not empty string. Top bar treats null
        // as "no subtitle"; an empty string would still render a
        // (blank) subtitle line.
        assertNull(inactiveEngineersSubtitle(0))
    }

    @Test fun `0 jobs in 30d literal is preserved verbatim`() {
        // Critical pin — the "0 jobs in 30d" suffix is a literal
        // constant (NOT computed from the rows), because the query
        // filters in exactly that condition. A refactor that tried
        // to compute it would couple the screen to an implicit stat.
        val out = inactiveEngineersSubtitle(1)
        assertTrue(out!!.endsWith("· 0 jobs in 30d"))
    }

    @Test fun `single row reads 1 verified (no singular special case)`() {
        // Pin — even on 1, says "1 verified". The verb is "are
        // verified" (implied), not a count-noun, so plural-blind.
        assertEquals(
            "1 verified · 0 jobs in 30d",
            inactiveEngineersSubtitle(1),
        )
    }

    @Test fun `middle dot is U+00B7`() {
        val out = inactiveEngineersSubtitle(1)
        assertTrue(out!!.contains(" · "))
    }
}
