package com.equipseva.app.features.repair.directory

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins two pure helpers on the engineer public profile header:
 *
 *   * formatCityStateLine — "City, State" join with null/blank-
 *     filtering so trailing commas / leading separators never leak.
 *   * formatHourlyRateOrDash — rupee-formatted hourly rate or
 *     em-dash (U+2014) fallback when null. Pin so a refactor to
 *     "Not set" / "₹0" doesn't drift — em-dash signals "data
 *     unavailable", NOT "engineer works for free".
 */
class PublicProfileHeaderHelpersTest {

    // ---- formatCityStateLine ----

    @Test fun `both city and state join with comma`() {
        assertEquals("Bengaluru, KA", formatCityStateLine("Bengaluru", "KA"))
    }

    @Test fun `null state shows city alone (no trailing comma)`() {
        assertEquals("Bengaluru", formatCityStateLine("Bengaluru", null))
    }

    @Test fun `null city shows state alone (no leading comma)`() {
        assertEquals("KA", formatCityStateLine(null, "KA"))
    }

    @Test fun `both null returns empty (caller hides the line)`() {
        assertEquals("", formatCityStateLine(null, null))
    }

    @Test fun `blank state same as null state`() {
        // Pin so an empty / whitespace state doesn't surface as
        // "Bengaluru, " trailing-comma garbage.
        assertEquals("Bengaluru", formatCityStateLine("Bengaluru", "  "))
        assertEquals("Bengaluru", formatCityStateLine("Bengaluru", ""))
    }

    @Test fun `blank city same as null city`() {
        assertEquals("KA", formatCityStateLine("  ", "KA"))
    }

    @Test fun `both blank returns empty`() {
        assertEquals("", formatCityStateLine("  ", "   "))
    }

    // ---- formatHourlyRateOrDash ----

    @Test fun `null hourly rate returns em-dash`() {
        // U+2014 EM DASH — signals "data unavailable", NOT "₹0".
        assertEquals("—", formatHourlyRateOrDash(null))
    }

    @Test fun `dash glyph is U+2014 not ASCII hyphen`() {
        val out = formatHourlyRateOrDash(null)
        assertEquals(true, out.contains('—'))
        assertEquals(false, out.contains('-'))
    }

    @Test fun `present rate formats with rupee sign and lakh grouping`() {
        assertEquals("₹750", formatHourlyRateOrDash(750.0))
        assertEquals("₹1,500", formatHourlyRateOrDash(1500.0))
    }

    @Test fun `lakh-scale rate uses Indian grouping (not Western)`() {
        // formatRupees applies lakh grouping — pin so the wrapper
        // doesn't accidentally re-format and lose it.
        assertEquals("₹1,00,000", formatHourlyRateOrDash(100000.0))
    }

    @Test fun `zero rate renders as zero rupees (NOT em-dash)`() {
        // 0 is a legitimate (if unusual) rate — pin so the helper
        // doesn't fold it to em-dash and hide a configured-zero
        // rate as if it were missing.
        assertEquals("₹0", formatHourlyRateOrDash(0.0))
    }
}
