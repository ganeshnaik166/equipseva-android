package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the three AMC SLA breach card helpers:
 *
 *   * amcSeverityLabel — Emergency vs Standard pill label.
 *   * amcBreachTypeLabel — wire kind → user-facing copy with a
 *     forward-compat verbatim fallback.
 *   * amcBreachWindowLine — "Expected within Xh · actual Yh" with
 *     the actual-segment dropped when still mid-flight, and Locale.US
 *     formatting so a comma-decimal locale doesn't render "5,2h".
 */
class AmcSlaBreachHelpersTest {

    // ---- amcSeverityLabel ----

    @Test fun `emergency severity renders the Emergency label`() {
        assertEquals("Emergency", amcSeverityLabel("emergency"))
    }

    @Test fun `non-emergency severities fold to Standard`() {
        assertEquals("Standard", amcSeverityLabel("standard"))
        assertEquals("Standard", amcSeverityLabel(null))
        assertEquals("Standard", amcSeverityLabel(""))
        assertEquals("Standard", amcSeverityLabel("future_severity"))
    }

    @Test fun `severity is case-sensitive`() {
        // wire format is lowercase; pin so a tolerant `lowercase()`
        // refactor doesn't get added.
        assertEquals("Standard", amcSeverityLabel("Emergency"))
        assertEquals("Standard", amcSeverityLabel("EMERGENCY"))
    }

    // ---- amcBreachTypeLabel ----

    @Test fun `response_time renders user-facing copy`() {
        assertEquals("Response time", amcBreachTypeLabel("response_time"))
    }

    @Test fun `no_show renders user-facing copy`() {
        assertEquals("No-show", amcBreachTypeLabel("no_show"))
    }

    @Test fun `quality renders user-facing copy`() {
        assertEquals("Quality", amcBreachTypeLabel("quality"))
    }

    @Test fun `unknown breach type passes through verbatim`() {
        // Forward-compat: a future server-side breach kind still
        // surfaces (raw snake_case) instead of vanishing.
        assertEquals("future_breach_kind", amcBreachTypeLabel("future_breach_kind"))
    }

    @Test fun `empty breach type yields empty (defensive)`() {
        assertEquals("", amcBreachTypeLabel(""))
    }

    // ---- amcBreachWindowLine ----

    @Test fun `actual hours present renders both segments`() {
        assertEquals(
            "Expected within 4h · actual 5.2h",
            amcBreachWindowLine(expectedWithinHours = 4, actualHours = 5.2),
        )
    }

    @Test fun `actual hours null drops the second segment`() {
        // Mid-flight breach (engineer still en route past the SLA)
        // — "actual" is unknown.
        assertEquals(
            "Expected within 4h",
            amcBreachWindowLine(expectedWithinHours = 4, actualHours = null),
        )
    }

    @Test fun `actual 0 still renders the segment (not treated as null)`() {
        // 0 is a legitimate value (immediate breach detection) —
        // pin so it doesn't collapse to "Expected within 4h" alone.
        val out = amcBreachWindowLine(expectedWithinHours = 4, actualHours = 0.0)
        assertEquals("Expected within 4h · actual 0.0h", out)
    }

    @Test fun `single-digit hours render with 1 decimal place`() {
        // %.1f forces a trailing decimal even on integral values
        // so the row stays visually aligned.
        assertEquals(
            "Expected within 1h · actual 1.0h",
            amcBreachWindowLine(expectedWithinHours = 1, actualHours = 1.0),
        )
    }

    @Test fun `large breach durations don't truncate`() {
        assertEquals(
            "Expected within 24h · actual 72.5h",
            amcBreachWindowLine(expectedWithinHours = 24, actualHours = 72.5),
        )
    }

    @Test fun `actual hours use Locale-US decimal (not comma)`() {
        // Defensive: a Hindi-default or French-default device locale
        // would otherwise render "5,2h" — pin Locale.US so the
        // decimal point stays a dot.
        val out = amcBreachWindowLine(expectedWithinHours = 4, actualHours = 5.2)
        assertEquals(0, out.count { it == ',' })
        assertEquals(1, out.count { it == '·' })
    }
}
