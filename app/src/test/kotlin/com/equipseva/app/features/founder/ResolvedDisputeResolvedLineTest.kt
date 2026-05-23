package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ResolvedDisputeResolvedLineTest {

    @Test fun `with resolvedByName surfaces middle-dot name suffix`() {
        assertEquals(
            "Resolved: 23 May 2026 14:30 · Founder Admin",
            resolvedDisputeResolvedLine(
                prettyResolvedAt = "23 May 2026 14:30",
                resolvedByName = "Founder Admin",
            ),
        )
    }

    @Test fun `null resolvedByName drops the suffix entirely`() {
        // Critical pin — no trailing dot or spaces. A refactor that
        // always appended " · " would surface "Resolved: X · " on
        // legacy rows.
        assertEquals(
            "Resolved: 23 May 2026 14:30",
            resolvedDisputeResolvedLine(
                prettyResolvedAt = "23 May 2026 14:30",
                resolvedByName = null,
            ),
        )
    }

    @Test fun `Resolved prefix preserved verbatim with colon-space`() {
        val out = resolvedDisputeResolvedLine("x", "y")
        assertTrue(out.startsWith("Resolved: "))
    }

    @Test fun `middle dot separator is U+00B7`() {
        val out = resolvedDisputeResolvedLine("x", "y")
        assertTrue(out.contains(" · "))
    }

    @Test fun `empty resolvedByName surfaces dot-empty (defensive — caller gates)`() {
        // Pin null gate (not isNullOrBlank). Empty string surfaces
        // as a naked trailing " · " — the wire shouldn't allow this
        // but pin total shape.
        assertEquals(
            "Resolved: x · ",
            resolvedDisputeResolvedLine("x", ""),
        )
    }
}
