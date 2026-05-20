package com.equipseva.app.features.repair.directory

import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the pure derivations extracted from EngineerDirectoryScreen +
 * EngineerPublicProfileScreen: directory location-line composer, the
 * 90+jobs/2 completion-fallback curve, the percent-vs-fraction
 * completion-rate formatter, the hero city/state joiner, the review
 * city suffix, the chip pretty-key, and the UiState.filteredRows
 * district + specialization filter. None of these need Compose or
 * Supabase to evaluate — keep them honest with plain JUnit.
 */
class EngineerDirectoryFormattersTest {

    // --- formatDirectoryRowLocationLine ----------------------------------

    @Test fun `location line joins city, distance, hourly with middots`() {
        // The card's three-component subtitle. Distance formats to one
        // decimal place (matches the design's "12.3 km" pattern); hourly
        // strips paise via toInt().
        assertEquals(
            "Hyderabad · 12.3 km · ₹1500/hr",
            formatDirectoryRowLocationLine(city = "Hyderabad", distanceKm = 12.34, hourlyRate = 1500.0),
        )
    }

    @Test fun `location line drops blank city + null distance`() {
        // Blank city is treated as missing so we don't render a leading
        // " · " separator. Same for null distance.
        assertEquals(
            "₹900/hr",
            formatDirectoryRowLocationLine(city = "   ", distanceKm = null, hourlyRate = 900.0),
        )
    }

    @Test fun `location line returns null when nothing renderable`() {
        // Caller skips the Text() node entirely on null — avoids an empty
        // string baseline-shifting the chip row below.
        assertNull(formatDirectoryRowLocationLine(city = null, distanceKm = null, hourlyRate = null))
        assertNull(formatDirectoryRowLocationLine(city = "", distanceKm = null, hourlyRate = null))
    }

    // --- computeFallbackCompletionPct ------------------------------------

    @Test fun `fallback completion floor is 90 for zero jobs`() {
        // New engineers shouldn't render a "0% complete" stat — the
        // fallback curve floors at 90% until they accrue history.
        assertEquals(90, computeFallbackCompletionPct(0))
    }

    @Test fun `fallback completion saturates at 100 after 20 jobs`() {
        // The curve adds 0.5pt per job up to 20 jobs, then clamps.
        // Pin the saturation point so a future tweak doesn't silently
        // let it climb to 105%+.
        assertEquals(100, computeFallbackCompletionPct(20))
        assertEquals(100, computeFallbackCompletionPct(500))
    }

    @Test fun `fallback completion curve at 10 jobs is 95`() {
        // Spot-check midpoint: 90 + (10 / 2) = 95.
        assertEquals(95, computeFallbackCompletionPct(10))
    }

    // --- formatCompletionRatePct -----------------------------------------

    @Test fun `completion rate as 0 to 1 fraction is scaled to percent`() {
        // Legacy seed data stored the value as a fraction. Detect by
        // magnitude (<=1.0 → fraction) and scale before truncation.
        assertEquals("85%", formatCompletionRatePct(0.85))
        assertEquals("100%", formatCompletionRatePct(1.0))
    }

    @Test fun `completion rate already 0 to 100 is rendered as is`() {
        // Current backend returns whole-percent — never scale a 98 to 9800.
        assertEquals("98%", formatCompletionRatePct(98.0))
        assertEquals("100%", formatCompletionRatePct(100.0))
    }

    @Test fun `completion rate zero stays zero percent`() {
        // 0.0 hits the <=1.0 branch but 0*100=0 — pin so we don't
        // accidentally render "—" instead.
        assertEquals("0%", formatCompletionRatePct(0.0))
    }

    // --- formatProfileCityStateLine --------------------------------------

    @Test fun `hero line joins city + state with comma`() {
        assertEquals("Hyderabad, Telangana", formatProfileCityStateLine("Hyderabad", "Telangana"))
    }

    @Test fun `hero line drops blanks so no stray comma`() {
        // Common shape: city present, state null. We must not render
        // "Hyderabad, " or ", Telangana".
        assertEquals("Hyderabad", formatProfileCityStateLine("Hyderabad", null))
        assertEquals("Telangana", formatProfileCityStateLine("  ", "Telangana"))
        assertEquals("", formatProfileCityStateLine(null, null))
        assertEquals("", formatProfileCityStateLine("", ""))
    }

    // --- formatReviewCitySuffix ------------------------------------------

    @Test fun `review city suffix prepends middot when present`() {
        // Pattern is "<relative time> · <city>". The middot lives in
        // the suffix so callers can concatenate without conditionals.
        assertEquals(" · Hyderabad", formatReviewCitySuffix("Hyderabad"))
    }

    @Test fun `review city suffix is empty for null or blank`() {
        // RPC redacts hospital identity → city often null. Must collapse
        // to "" so we don't render a dangling " · " after the timestamp.
        assertEquals("", formatReviewCitySuffix(null))
        assertEquals("", formatReviewCitySuffix("   "))
    }

    // --- prettyKeyLabel --------------------------------------------------

    @Test fun `prettyKeyLabel title-cases snake and kebab tokens`() {
        // Specialization slugs from the RPC come snake_cased; chip
        // renderer needs human labels.
        assertEquals("Patient Monitor", prettyKeyLabel("patient_monitor"))
        assertEquals("X Ray", prettyKeyLabel("x-ray"))
        assertEquals("Mri Scanner", prettyKeyLabel("mri_scanner"))
    }

    @Test fun `prettyKeyLabel passes single token unchanged casing`() {
        // Capitalizes the first char only — preserves existing token
        // shape (matches design's "Imaging" not "IMAGING").
        assertEquals("Imaging", prettyKeyLabel("imaging"))
    }

    // --- UiState.filteredRows --------------------------------------------

    @Test fun `filteredRows returns all rows when district is All Telangana and spec is null`() {
        // The default landing state — no filters applied, every row in
        // the RPC response should be visible.
        val rows = listOf(row("a", city = "Hyderabad"), row("b", city = "Khammam"))
        val state = EngineerDirectoryViewModel.UiState(
            district = "All Telangana",
            specialization = null,
            rows = rows,
        )
        assertEquals(rows, state.filteredRows)
    }

    @Test fun `filteredRows narrows by district case-insensitively`() {
        // Backend stores city in whatever case the engineer typed —
        // chip values are TitleCase. Match must be case-insensitive so
        // "hyderabad" matches "Hyderabad".
        val rows = listOf(
            row("a", city = "hyderabad"),
            row("b", city = "Khammam"),
            row("c", city = null),
        )
        val state = EngineerDirectoryViewModel.UiState(
            district = "Hyderabad",
            rows = rows,
        )
        assertEquals(listOf("a"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `filteredRows narrows by specialization case-insensitively`() {
        // Specialization chip values are TitleCase ("Imaging") but RPC
        // returns lowercase slugs. Match case-insensitive across the
        // engineer's full spec list.
        val rows = listOf(
            row("a", specializations = listOf("imaging", "ultrasound")),
            row("b", specializations = listOf("dental")),
            row("c", specializations = null),
        )
        val state = EngineerDirectoryViewModel.UiState(
            specialization = "Imaging",
            rows = rows,
        )
        assertEquals(listOf("a"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `filteredRows combines district + specialization filters with AND`() {
        // Both filters active → only rows matching both pass.
        val rows = listOf(
            row("a", city = "Hyderabad", specializations = listOf("Imaging")),
            row("b", city = "Hyderabad", specializations = listOf("Dental")),
            row("c", city = "Khammam", specializations = listOf("Imaging")),
        )
        val state = EngineerDirectoryViewModel.UiState(
            district = "Hyderabad",
            specialization = "Imaging",
            rows = rows,
        )
        assertEquals(listOf("a"), state.filteredRows.map { it.engineerId })
    }

    private fun row(
        id: String,
        city: String? = null,
        specializations: List<String>? = null,
    ): EngineerDirectoryRepository.DirectoryRow = EngineerDirectoryRepository.DirectoryRow(
        engineerId = id,
        fullName = "Engineer $id",
        city = city,
        specializations = specializations,
    )
}
