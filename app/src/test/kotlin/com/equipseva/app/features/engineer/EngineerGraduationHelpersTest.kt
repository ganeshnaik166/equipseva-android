package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins for the r1390 tier-benefit helpers that back the cockpit's
 * "Tier benefits" cards (r550 engineer_certification_tiers seed:
 * none/bronze 7%, silver 6% + featured, gold 5% + featured + PI insurance).
 */
class EngineerGraduationHelpersTest {

    @Test fun `whole-number fee drops the decimal`() {
        assertEquals("5", formatFeePct(5.0))
        assertEquals("7", formatFeePct(7.0))
    }

    @Test fun `fractional fee keeps one decimal, locale-stable`() {
        // Locale.ROOT — a comma-decimal locale must never render "6,5".
        assertEquals("6.5", formatFeePct(6.5))
    }

    @Test fun `bronze-style tier lists only the platform fee`() {
        assertEquals(
            listOf("7% platform fee"),
            tierBenefitLines(7.0, piInsuranceEligible = false, featuredInSearch = false, codeRedPriority = 0),
        )
    }

    @Test fun `silver adds featured-in-search`() {
        assertEquals(
            listOf("6% platform fee", "Featured in search"),
            tierBenefitLines(6.0, piInsuranceEligible = false, featuredInSearch = true, codeRedPriority = 0),
        )
    }

    @Test fun `gold unlocks insurance, featured and code-red priority`() {
        assertEquals(
            listOf(
                "5% platform fee",
                "Free PI insurance",
                "Featured in search",
                "Code Red priority dispatch",
            ),
            tierBenefitLines(5.0, piInsuranceEligible = true, featuredInSearch = true, codeRedPriority = 2),
        )
    }

    @Test fun `code-red priority only appears when strictly positive`() {
        val lines = tierBenefitLines(5.0, piInsuranceEligible = false, featuredInSearch = false, codeRedPriority = 0)
        assertEquals(listOf("5% platform fee"), lines)
    }

    @Test fun `platform fee is always first`() {
        // Pin display order so a refactor can't reshuffle the benefit list.
        val lines = tierBenefitLines(5.0, piInsuranceEligible = true, featuredInSearch = true, codeRedPriority = 1)
        assertEquals(0, lines.indexOfFirst { it.endsWith("platform fee") })
    }
}
