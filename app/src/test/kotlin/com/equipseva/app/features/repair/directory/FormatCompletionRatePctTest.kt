package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the dual-shape completion-rate formatter. The wire column
 * type drifted between fraction (0..1) and percentage (0..100)
 * during v1 migrations; the helper tolerates both.
 *
 * Critical regions:
 *   * Heuristic boundary at 1.0 — values ≤ 1.0 are fractions, > 1.0
 *     are already percentages. A regression that always multiplied
 *     would surface "9700%" on a 97.0 input; one that never
 *     multiplied would surface "0%" on a 0.97 input.
 *   * Result truncated to Int (no rounding) — "97.7%" reads as
 *     "97%". Pin so a refactor to Math.round doesn't drift.
 */
class FormatCompletionRatePctTest {

    @Test fun `fraction 0_97 maps to 97 percent`() {
        assertEquals("97%", formatCompletionRatePct(0.97))
    }

    @Test fun `fraction 1_0 maps to 100 percent (boundary inclusive)`() {
        // 1.0 is treated as a fraction (1.0 * 100 = 100) — pin the
        // inclusive boundary.
        assertEquals("100%", formatCompletionRatePct(1.0))
    }

    @Test fun `percentage 97_0 maps to 97 percent`() {
        // > 1.0 path — value is already a percentage.
        assertEquals("97%", formatCompletionRatePct(97.0))
    }

    @Test fun `percentage 100_0 maps to 100 percent`() {
        assertEquals("100%", formatCompletionRatePct(100.0))
    }

    @Test fun `fraction 0_5 maps to 50 percent`() {
        assertEquals("50%", formatCompletionRatePct(0.5))
    }

    @Test fun `fraction 0 maps to 0 percent (no engineers completed)`() {
        assertEquals("0%", formatCompletionRatePct(0.0))
    }

    @Test fun `fractional percentage 97_7 truncates to 97 percent (no rounding)`() {
        // Int truncation, not rounding. Pin so a refactor to
        // Math.round("97.7" → 98) doesn't drift.
        assertEquals("97%", formatCompletionRatePct(97.7))
    }

    @Test fun `value just above 1_0 takes percentage path`() {
        // 1.5 reads as 1.5% (already a percentage), not 150% (would
        // be the fraction path). The boundary is "<= 1.0 fraction".
        assertEquals("1%", formatCompletionRatePct(1.5))
    }

    @Test fun `value 100 boundary stays percentage`() {
        assertEquals("100%", formatCompletionRatePct(100.0))
    }

    @Test fun `large percentage value passes through (defensive)`() {
        // Server-side cap should prevent >100 but pin a sensible
        // fallback so the helper is total.
        assertEquals("150%", formatCompletionRatePct(150.0))
    }
}
