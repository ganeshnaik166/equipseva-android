package com.equipseva.app.features.repair.directory

import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the engineer-directory UiState derivations:
 *
 *   * `filteredRows` — three-condition gate: isBookable (rate +
 *     specializations both present), matchesDistrict, matchesSpec.
 *     The bookable check is the easy regression — without it, fresh
 *     engineers with verified KYC but no profile basics would still
 *     surface alongside complete profiles, making the Verified badge
 *     meaningless.
 *   * `hasLocation` — composite "we have coords" gate; drives
 *     whether the "Nearest" sort chip is enabled.
 */
class EngineerDirectoryUiStateTest {

    private fun row(
        id: String = "e1",
        fullName: String = "Ravi Kumar",
        city: String? = "Hyderabad",
        specializations: List<String>? = listOf("imaging"),
        hourlyRate: Double? = 750.0,
    ): EngineerDirectoryRepository.DirectoryRow =
        EngineerDirectoryRepository.DirectoryRow(
            engineerId = id,
            userId = "u-$id",
            fullName = fullName,
            avatarUrl = null,
            city = city,
            state = "Telangana",
            serviceAreas = null,
            specializations = specializations,
            brandsServiced = null,
            experienceYears = 5,
            ratingAvg = 4.6,
            totalJobs = 30,
            hourlyRate = hourlyRate,
            bio = null,
            isAvailable = true,
            distanceKm = null,
        )

    // ---- isBookable gate ----

    @Test fun `row without hourly rate is filtered out`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "complete"),
                row(id = "no-rate", hourlyRate = null),
            ),
        )
        assertEquals(listOf("complete"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `row without specializations is filtered out`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "complete"),
                row(id = "no-specs", specializations = null),
                row(id = "empty-specs", specializations = emptyList()),
            ),
        )
        assertEquals(listOf("complete"), state.filteredRows.map { it.engineerId })
    }

    // ---- district gate ----

    @Test fun `district 'All Telangana' is a wildcard (matches every row)`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(row(id = "h", city = "Hyderabad"), row(id = "w", city = "Warangal")),
            district = "All Telangana",
        )
        assertEquals(listOf("h", "w"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `specific district keeps only matching city (case-insensitive)`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "h", city = "Hyderabad"),
                row(id = "w", city = "Warangal"),
                row(id = "h2", city = "hyderabad"),  // case variation
            ),
            district = "Hyderabad",
        )
        assertEquals(listOf("h", "h2"), state.filteredRows.map { it.engineerId })
    }

    // ---- specialization gate ----

    @Test fun `null specialization filter passes everything`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "a", specializations = listOf("imaging")),
                row(id = "b", specializations = listOf("dental")),
            ),
            specialization = null,
        )
        assertEquals(listOf("a", "b"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `specialization filter is case-insensitive`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "ok", specializations = listOf("Imaging")),
                row(id = "no", specializations = listOf("dental")),
            ),
            specialization = "imaging",
        )
        assertEquals(listOf("ok"), state.filteredRows.map { it.engineerId })
    }

    @Test fun `specialization filter matches when engineer has multiple specs`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "many", specializations = listOf("imaging", "dental", "neonatal")),
            ),
            specialization = "neonatal",
        )
        assertEquals(listOf("many"), state.filteredRows.map { it.engineerId })
    }

    // ---- combined gates ----

    @Test fun `all three filters compose with AND semantics`() {
        val state = EngineerDirectoryViewModel.UiState(
            loading = false,
            rows = listOf(
                row(id = "match", city = "Hyderabad", specializations = listOf("imaging")),
                row(id = "wrong-city", city = "Warangal", specializations = listOf("imaging")),
                row(
                    id = "wrong-spec",
                    city = "Hyderabad",
                    specializations = listOf("dental"),
                ),
                row(id = "no-rate", city = "Hyderabad", hourlyRate = null),
            ),
            district = "Hyderabad",
            specialization = "imaging",
        )
        assertEquals(listOf("match"), state.filteredRows.map { it.engineerId })
    }

    // ---- hasLocation ----

    @Test fun `hasLocation false when either coord is null`() {
        assertFalse(EngineerDirectoryViewModel.UiState().hasLocation)
        assertFalse(
            EngineerDirectoryViewModel.UiState(hospitalLat = 12.97).hasLocation,
        )
        assertFalse(
            EngineerDirectoryViewModel.UiState(hospitalLng = 77.59).hasLocation,
        )
    }

    @Test fun `hasLocation true when both coords are non-null`() {
        val state = EngineerDirectoryViewModel.UiState(
            hospitalLat = 12.97,
            hospitalLng = 77.59,
        )
        assertTrue(state.hasLocation)
    }
}
