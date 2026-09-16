package com.equipseva.app.features.hospital

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Pins the four visual states of the hospital's active-jobs list as
 * Roborazzi goldens. Renders the stateless Content body directly, so
 * no Hilt graph or ViewModel is involved.
 *
 * Fixture rows leave createdAtInstant null on purpose: the card's
 * "Posted Nd ago" fallback and the right-hand "Nd ago" both derive
 * from Instant.now(), which would make the golden drift daily. With
 * a schedule present and no posted-at, the card renders only the
 * fixed schedule line.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class HospitalActiveJobsScreenScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/HospitalActiveJobsScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: HospitalActiveJobsViewModel.UiState) {
        HospitalActiveJobsContent(
            state = state,
            onFilterChange = {},
            onRefresh = {},
            onBack = {},
            onJobClick = {},
            onRequestRepair = {},
        )
    }

    @Test
    fun loading() = capture("loading") {
        Content(state = HospitalActiveJobsViewModel.UiState(loading = true))
    }

    @Test
    fun empty() = capture("empty") {
        Content(
            state = HospitalActiveJobsViewModel.UiState(
                loading = false,
                filter = HospitalActiveJobsViewModel.Filter.All,
            ),
        )
    }

    @Test
    fun error() = capture("error") {
        Content(
            state = HospitalActiveJobsViewModel.UiState(
                loading = false,
                errorMessage = "Couldn't load repair jobs. Check your connection and try again.",
            ),
        )
    }

    @Test
    fun populated() = capture("populated") {
        Content(
            state = HospitalActiveJobsViewModel.UiState(
                loading = false,
                openJobs = listOf(
                    fixtureJob(
                        id = "RPR-00041",
                        status = RepairJobStatus.Requested,
                        urgency = RepairJobUrgency.Emergency,
                        equipmentBrand = "Philips",
                        equipmentModel = "IntelliVue MX450",
                        issueDescription = "Monitor reboots every few minutes; ECG trace drops out.",
                        siteLocation = "ICU, 3rd floor, Apollo Hospitals, Jubilee Hills",
                        scheduledDate = "18 Sep 2026",
                        scheduledTimeSlot = "10:00 - 12:00",
                    ),
                ),
                inProgressJobs = listOf(
                    fixtureJob(
                        id = "RPR-00038",
                        status = RepairJobStatus.InProgress,
                        urgency = RepairJobUrgency.SameDay,
                        equipmentBrand = "Mindray",
                        equipmentModel = "BC-5150",
                        issueDescription = "Haematology analyser flags reagent pressure error on every run.",
                        siteLocation = "Central lab, ground floor",
                        scheduledDate = "16 Sep 2026",
                        scheduledTimeSlot = "14:00 - 16:00",
                    ),
                ),
                closedJobs = listOf(
                    fixtureJob(
                        id = "RPR-00029",
                        status = RepairJobStatus.Completed,
                        urgency = RepairJobUrgency.Scheduled,
                        equipmentBrand = "Getinge",
                        equipmentModel = "HS66 Steriliser",
                        issueDescription = "Chamber door seal leaking steam mid-cycle.",
                        siteLocation = "CSSD, basement",
                        scheduledDate = "09 Sep 2026",
                        scheduledTimeSlot = "09:00 - 11:00",
                    ),
                    fixtureJob(
                        id = "RPR-00022",
                        status = RepairJobStatus.Cancelled,
                        urgency = RepairJobUrgency.Scheduled,
                        equipmentBrand = null,
                        equipmentModel = null,
                        equipmentCategory = RepairEquipmentCategory.Dental,
                        issueDescription = "Dental chair hydraulics not lifting.",
                        siteLocation = null,
                        scheduledDate = "02 Sep 2026",
                        scheduledTimeSlot = null,
                        cancellationReason = "Engineer self-repaired on site",
                    ),
                ),
            ),
        )
    }

    private fun fixtureJob(
        id: String,
        status: RepairJobStatus,
        urgency: RepairJobUrgency,
        equipmentBrand: String?,
        equipmentModel: String?,
        issueDescription: String,
        siteLocation: String?,
        scheduledDate: String?,
        scheduledTimeSlot: String?,
        equipmentCategory: RepairEquipmentCategory = RepairEquipmentCategory.PatientMonitoring,
        cancellationReason: String? = null,
    ): RepairJob = RepairJob(
        id = id,
        jobNumber = id,
        title = issueDescription,
        issueDescription = issueDescription,
        equipmentCategory = equipmentCategory,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        status = status,
        urgency = urgency,
        estimatedCostRupees = 4500.0,
        scheduledDate = scheduledDate,
        scheduledTimeSlot = scheduledTimeSlot,
        siteLocation = siteLocation,
        isAssignedToEngineer = status != RepairJobStatus.Requested,
        engineerId = if (status != RepairJobStatus.Requested) "ENG-0007" else null,
        hospitalUserId = "HOSP-0001",
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
        cancellationReason = cancellationReason,
    )
}
