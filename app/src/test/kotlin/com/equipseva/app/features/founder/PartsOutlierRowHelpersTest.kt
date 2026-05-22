package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * Pins the five helpers behind the founder's parts-cost-outlier row.
 * Critical surfaces include the locale-stable ratio formatter (so a
 * Hindi-locale device doesn't render "3,2×"), the Unicode glyphs
 * (U+00D7 multiplication sign, U+2192 arrow), and the role-aware
 * fallbacks for legacy backfill rows.
 */
class PartsOutlierRowHelpersTest {

    // ---- partsOutlierRowTitle ----------------------------------------

    @Test fun `server jobNumber wins when present`() {
        assertEquals(
            "RPR-2026-00041",
            partsOutlierRowTitle("RPR-2026-00041", "abcdefghijklmnop"),
        )
    }

    @Test fun `null jobNumber falls back to RPR plus 6-char id prefix`() {
        // Critical pin — take(6) NOT take(8). The outlier queue uses
        // 6 to align with the server jobNumber suffix length.
        assertEquals(
            "RPR-abcdef",
            partsOutlierRowTitle(null, "abcdefghijklmnop"),
        )
    }

    @Test fun `jobNumber empty string is taken verbatim, not folded to fallback`() {
        // Pin the exact null-only gate. If a backfill row stores ""
        // (zero-length but non-null) we render the empty title rather
        // than masking the data bug. A refactor that switched to
        // `isNullOrBlank` would silently absorb the bug.
        assertEquals("", partsOutlierRowTitle("", "abcdefxyz"))
    }

    @Test fun `short repair job id is left intact in the fallback`() {
        // take(6) on a string shorter than 6 returns the original
        // string — pin so a refactor to substring(0, 6) (which would
        // throw) surfaces here.
        assertEquals("RPR-abc", partsOutlierRowTitle(null, "abc"))
    }

    // ---- partsOutlierEquipmentTypeLabel ------------------------------

    @Test fun `snake case equipment type gets spaces and first capital`() {
        assertEquals("Mri scanner", partsOutlierEquipmentTypeLabel("mri_scanner"))
    }

    @Test fun `null equipment type reads Unknown`() {
        assertEquals("Unknown", partsOutlierEquipmentTypeLabel(null))
    }

    @Test fun `single-word equipment type still gets capitalised`() {
        assertEquals("Xray", partsOutlierEquipmentTypeLabel("xray"))
    }

    @Test fun `multi-underscore equipment type replaces all underscores`() {
        assertEquals(
            "Portable ct scanner",
            partsOutlierEquipmentTypeLabel("portable_ct_scanner"),
        )
    }

    // ---- partsOutlierRatioPillText -----------------------------------

    @Test fun `ratio renders with one decimal and U+00D7 multiplication sign`() {
        assertEquals("3.2×", partsOutlierRatioPillText(3.2))
    }

    @Test fun `ratio formatter is Locale-US stable, not device-locale`() {
        // Critical regression target — Hindi/German locale would render
        // "3,2" if Locale.US were dropped. Pin by setting and restoring
        // the default locale around the call.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals("5.7×", partsOutlierRatioPillText(5.7))
            Locale.setDefault(Locale.GERMANY)
            assertEquals("5.7×", partsOutlierRatioPillText(5.7))
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `ratio with no fractional part still shows one decimal`() {
        // Pin so a refactor to %g or %d wouldn't surface "5×" instead
        // of "5.0×" — the .0 is intentional for visual alignment with
        // 5.x and 6.x rows in the list.
        assertEquals("5.0×", partsOutlierRatioPillText(5.0))
    }

    @Test fun `ratio rounds to one decimal half-up`() {
        // %.1f does half-up rounding — pin so a precision refactor
        // surfaces here.
        assertEquals("3.3×", partsOutlierRatioPillText(3.25))
    }

    @Test fun `multiplication sign is U+00D7 not ASCII x`() {
        val text = partsOutlierRatioPillText(2.0)
        assertTrue(text.endsWith("×"))
        assertTrue(text.contains('×'))
        assertEquals(false, text.endsWith("x"))
    }

    // ---- partsOutlierComparisonLine ----------------------------------

    @Test fun `comparison line renders both values with Parts and vs prefixes`() {
        val line = partsOutlierComparisonLine(50_000.0, 10_000.0)
        // formatRupees adds the ₹ symbol with Indian-lakh grouping —
        // pin the surrounding prose verbatim.
        assertTrue(line.startsWith("Parts "))
        assertTrue(line.contains(" vs category avg "))
    }

    @Test fun `comparison line preserves vs category avg phrasing exactly`() {
        // Pin literal — a refactor to "Category avg" or "vs avg" would
        // surface here.
        val line = partsOutlierComparisonLine(1.0, 1.0)
        assertTrue(line.contains("vs category avg"))
    }

    // ---- partsOutlierPartiesLine -------------------------------------

    @Test fun `parties line joins engineer and hospital with U+2192 arrow`() {
        assertEquals(
            "Asha Rao → Apollo Hyderabad",
            partsOutlierPartiesLine("Asha Rao", "Apollo Hyderabad"),
        )
    }

    @Test fun `null engineer falls back to Engineer role label`() {
        assertEquals(
            "Engineer → Apollo Hyderabad",
            partsOutlierPartiesLine(null, "Apollo Hyderabad"),
        )
    }

    @Test fun `null hospital falls back to Hospital role label`() {
        assertEquals(
            "Asha Rao → Hospital",
            partsOutlierPartiesLine("Asha Rao", null),
        )
    }

    @Test fun `both null fall back to role labels on both sides`() {
        assertEquals("Engineer → Hospital", partsOutlierPartiesLine(null, null))
    }

    @Test fun `blank engineer or hospital folds to role label too`() {
        assertEquals(
            "Engineer → Hospital",
            partsOutlierPartiesLine("   ", ""),
        )
    }

    @Test fun `arrow glyph is U+2192 not ASCII pointer`() {
        val line = partsOutlierPartiesLine("A", "B")
        assertTrue(line.contains('→'))
        assertEquals(false, line.contains("->"))
    }
}
