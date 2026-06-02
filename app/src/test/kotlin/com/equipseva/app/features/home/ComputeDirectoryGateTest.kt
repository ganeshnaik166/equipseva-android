package com.equipseva.app.features.home

import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Tests the gate-derivation that powers the engineer-side
 * directory-visibility banner. The gate must mirror the hospital-side
 * `isBookable` predicate exactly: an engineer is shown to hospitals iff
 * hourly_rate > 0 AND specializations is non-empty. Any drift between
 * the two predicates re-introduces the silent-invisibility bug
 * (Repair1 / Engineer Test / Play Review Engineer scenario).
 */
class ComputeDirectoryGateTest {

    /** Minimal Engineer fixture — fills non-defaulted required fields
     *  with empty/zero so each test only varies the two gate inputs. */
    private fun engineer(
        hourlyRate: Double?,
        specializations: List<RepairEquipmentCategory>,
    ): Engineer = Engineer(
        id = "eng-id",
        userId = "user-id",
        aadhaarNumber = null,
        aadhaarVerified = false,
        qualifications = emptyList(),
        specializations = specializations,
        brandsServiced = emptyList(),
        experienceYears = 0,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = VerificationStatus.Verified,
        backgroundCheckStatus = VerificationStatus.Pending,
        certificates = emptyList(),
        hourlyRate = hourlyRate,
    )

    @Test fun `rate set and specs set yields Visible`() {
        val g = computeDirectoryGate(
            engineer(
                hourlyRate = 500.0,
                specializations = listOf(RepairEquipmentCategory.ImagingRadiology),
            ),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.Visible, g)
    }

    @Test fun `null rate yields MissingRate when specs set`() {
        val g = computeDirectoryGate(
            engineer(hourlyRate = null, specializations = listOf(RepairEquipmentCategory.Surgical)),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingRate, g)
    }

    @Test fun `zero rate counts as missing rate`() {
        // Hospitals filter by "rate set"; 0.00 is a sentinel value that
        // surfaces as "Rate on request" — not useful for filtering, so
        // treat as missing.
        val g = computeDirectoryGate(
            engineer(hourlyRate = 0.0, specializations = listOf(RepairEquipmentCategory.Surgical)),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingRate, g)
    }

    @Test fun `negative rate (shouldn't happen but) counts as missing`() {
        val g = computeDirectoryGate(
            engineer(hourlyRate = -1.0, specializations = listOf(RepairEquipmentCategory.Surgical)),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingRate, g)
    }

    @Test fun `empty specs yields MissingSpecs when rate set`() {
        val g = computeDirectoryGate(
            engineer(hourlyRate = 500.0, specializations = emptyList()),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingSpecs, g)
    }

    @Test fun `both missing yields MissingBoth`() {
        val g = computeDirectoryGate(
            engineer(hourlyRate = null, specializations = emptyList()),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingBoth, g)
    }

    @Test fun `both null-and-empty yields MissingBoth (sentinel coverage)`() {
        val g = computeDirectoryGate(
            engineer(hourlyRate = 0.0, specializations = emptyList()),
        )
        assertEquals(HomeHubViewModel.DirectoryGate.MissingBoth, g)
    }
}
