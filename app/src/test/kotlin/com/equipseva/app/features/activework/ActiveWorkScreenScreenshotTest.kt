package com.equipseva.app.features.activework

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
 * Pins the four visual states of the engineer Active-Work list as
 * Roborazzi goldens. Rows deliberately carry a null createdAtInstant so
 * the card's "posted" label renders the fixed "Just now" fallback and the
 * golden never drifts with the wall clock.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class ActiveWorkScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/ActiveWorkScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: ActiveWorkViewModel.UiState) {
        ActiveWorkContent(
            state = state,
            onRefresh = {},
            onBack = {},
            onJobClick = {},
            onBrowseOpenJobs = {},
        )
    }

    @Test fun loading() = capture("loading") {
        Content(state = ActiveWorkViewModel.UiState(loading = true))
    }

    @Test fun empty() = capture("empty") {
        Content(state = ActiveWorkViewModel.UiState(loading = false))
    }

    @Test fun error() = capture("error") {
        Content(
            state = ActiveWorkViewModel.UiState(
                loading = false,
                errorMessage = "Couldn't reach the server. Check your connection and try again.",
            ),
        )
    }

    @Test fun populated() = capture("populated") {
        Content(
            state = ActiveWorkViewModel.UiState(
                loading = false,
                activeJobs = listOf(
                    fixtureJob(
                        id = "RPR-00041",
                        jobNumber = "EQ-2041",
                        status = RepairJobStatus.Assigned,
                        category = RepairEquipmentCategory.PatientMonitoring,
                        brand = "Philips",
                        model = "IntelliVue MX450",
                        issue = "Monitor reboots every few minutes; SpO2 trace drops out.",
                        site = "Apollo Hospitals, Jubilee Hills",
                        scheduledDate = "18 Sep",
                        scheduledTimeSlot = "10:00 - 12:00",
                        urgency = RepairJobUrgency.SameDay,
                    ),
                    fixtureJob(
                        id = "RPR-00042",
                        jobNumber = "EQ-2042",
                        status = RepairJobStatus.EnRoute,
                        category = RepairEquipmentCategory.Laboratory,
                        brand = "Mindray",
                        model = "BC-5150",
                        issue = "Haematology analyser aspirating air; low-sample alarm on every run.",
                        site = "Yashoda Hospitals, Somajiguda",
                        scheduledDate = "17 Sep",
                        scheduledTimeSlot = "14:00 - 16:00",
                        urgency = RepairJobUrgency.Emergency,
                    ),
                    fixtureJob(
                        id = "RPR-00043",
                        jobNumber = "EQ-2043",
                        status = RepairJobStatus.InProgress,
                        category = RepairEquipmentCategory.Sterilization,
                        brand = null,
                        model = null,
                        issue = "Autoclave door gasket leaking steam mid-cycle.",
                        site = "Care Hospitals, Banjara Hills",
                        scheduledDate = null,
                        scheduledTimeSlot = null,
                        urgency = RepairJobUrgency.Scheduled,
                    ),
                ),
                completedJobs = listOf(
                    fixtureJob(
                        id = "RPR-00039",
                        jobNumber = "EQ-2039",
                        status = RepairJobStatus.Completed,
                        category = RepairEquipmentCategory.Dental,
                        brand = "Confident",
                        model = "Nova Chair",
                        issue = "Chair hydraulics not lifting; foot pedal unresponsive.",
                        site = "Smile Dental Clinic, Kondapur",
                        scheduledDate = "12 Sep",
                        scheduledTimeSlot = "09:00 - 11:00",
                        urgency = RepairJobUrgency.Scheduled,
                        contractedAmountRupees = 4500.0,
                    ),
                    fixtureJob(
                        id = "RPR-00037",
                        jobNumber = "EQ-2037",
                        status = RepairJobStatus.Cancelled,
                        category = RepairEquipmentCategory.Ophthalmology,
                        brand = "Topcon",
                        model = "TRC-NW400",
                        issue = "Fundus camera flash not firing.",
                        site = "LV Prasad Eye Institute, Banjara Hills",
                        scheduledDate = "10 Sep",
                        scheduledTimeSlot = null,
                        urgency = RepairJobUrgency.Unknown,
                        cancellationReason = "Hospital resolved in-house",
                    ),
                ),
                queuedStatusCount = 1,
            ),
        )
    }

    private fun fixtureJob(
        id: String,
        jobNumber: String,
        status: RepairJobStatus,
        category: RepairEquipmentCategory,
        brand: String?,
        model: String?,
        issue: String,
        site: String,
        scheduledDate: String?,
        scheduledTimeSlot: String?,
        urgency: RepairJobUrgency,
        contractedAmountRupees: Double? = null,
        cancellationReason: String? = null,
    ): RepairJob = RepairJob(
        id = id,
        jobNumber = jobNumber,
        title = issue,
        issueDescription = issue,
        equipmentCategory = category,
        equipmentBrand = brand,
        equipmentModel = model,
        status = status,
        urgency = urgency,
        estimatedCostRupees = 3500.0,
        contractedAmountRupees = contractedAmountRupees,
        scheduledDate = scheduledDate,
        scheduledTimeSlot = scheduledTimeSlot,
        siteLocation = site,
        isAssignedToEngineer = true,
        engineerId = "ENG-0007",
        hospitalUserId = "HOSP-0102",
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
