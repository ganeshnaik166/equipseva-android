package com.equipseva.app.features.mybids

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
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
 * Pins the visual states of the My-Bids screen as Roborazzi goldens. The
 * list only ever shows the active chip's status, so the Accepted tab gets
 * its own fixture: it is the sole place the green Success pill and the
 * "Preview payout" link are rendered.
 *
 * Fixtures deliberately leave `createdAtInstant` null: the row caption is a
 * relative "Placed 3d ago" derived from the wall clock, so any fixed instant
 * would drift the golden week over week. The bid amount, status pill, chip
 * counts and empty/error copy are all clock-independent.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class MyBidsScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/MyBidsScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: MyBidsViewModel.UiState) {
        MyBidsContent(
            state = state,
            onRefresh = {},
            onStatusFilterChange = {},
            onBack = {},
            onJobClick = {},
            onBrowseJobs = {},
            onCheckProfitability = {},
            onPreviewPayout = {},
        )
    }

    @Test fun loading() = capture("loading") {
        Content(state = MyBidsViewModel.UiState(loading = true, rows = emptyList()))
    }

    @Test fun empty() = capture("empty") {
        Content(state = MyBidsViewModel.UiState(loading = false, rows = emptyList(), statusFilter = null))
    }

    @Test fun error() = capture("error") {
        Content(
            state = MyBidsViewModel.UiState(
                loading = false,
                rows = emptyList(),
                errorMessage = "Couldn't load your bids. Check your connection and try again.",
            ),
        )
    }

    @Test fun populated() = capture("populated") {
        Content(
            state = MyBidsViewModel.UiState(
                loading = false,
                rows = populatedRows,
                statusFilter = null,
                queuedBidCount = 1,
            ),
        )
    }

    @Test fun accepted() = capture("accepted") {
        Content(
            state = MyBidsViewModel.UiState(
                loading = false,
                rows = populatedRows,
                statusFilter = RepairBidStatus.Accepted,
            ),
        )
    }

    private val populatedRows: List<MyBidsViewModel.MyBidRow> = listOf(
        row(
            bidId = "RPR-00041",
            jobId = "job-00041",
            amount = 4500.0,
            status = RepairBidStatus.Pending,
            job = job(
                id = "job-00041",
                title = "Ultrasound probe not detected",
                brand = "GE",
                model = "Logiq P5",
                category = RepairEquipmentCategory.ImagingRadiology,
                siteLocation = "Apollo Hospitals, Jubilee Hills",
            ),
        ),
        row(
            bidId = "RPR-00042",
            jobId = "job-00042",
            amount = 12500.0,
            status = RepairBidStatus.Pending,
            job = job(
                id = "job-00042",
                title = "Ventilator alarm fault",
                brand = "Dräger",
                model = "Evita V300",
                category = RepairEquipmentCategory.LifeSupport,
                siteLocation = "KIMS Hospital, Secunderabad",
            ),
        ),
        row(
            bidId = "RPR-00043",
            jobId = "job-00043",
            amount = 2800.0,
            status = RepairBidStatus.Pending,
            job = job(
                id = "job-00043",
                title = "Patient monitor screen flicker",
                brand = null,
                model = null,
                category = RepairEquipmentCategory.PatientMonitoring,
                siteLocation = null,
            ),
        ),
        row(
            bidId = "RPR-00044",
            jobId = "job-00044",
            amount = 9800.0,
            status = RepairBidStatus.Accepted,
            job = job(
                id = "job-00044",
                title = "Autoclave not reaching pressure",
                brand = "Tuttnauer",
                model = "3870EA",
                category = RepairEquipmentCategory.Sterilization,
                siteLocation = "Care Hospitals, Banjara Hills",
            ),
        ),
        row(
            bidId = "RPR-00045",
            jobId = "job-00045",
            amount = 6200.0,
            status = RepairBidStatus.Rejected,
            job = null,
        ),
    )

    private fun row(
        bidId: String,
        jobId: String,
        amount: Double,
        status: RepairBidStatus,
        job: RepairJob?,
    ): MyBidsViewModel.MyBidRow = MyBidsViewModel.MyBidRow(
        bid = RepairBid(
            id = bidId,
            repairJobId = jobId,
            engineerUserId = "eng-0007",
            amountRupees = amount,
            etaHours = 4,
            note = null,
            status = status,
            createdAtInstant = null,
            updatedAtInstant = null,
        ),
        job = job,
    )

    private fun job(
        id: String,
        title: String,
        brand: String?,
        model: String?,
        category: RepairEquipmentCategory,
        siteLocation: String?,
    ): RepairJob = RepairJob(
        id = id,
        jobNumber = null,
        title = title,
        issueDescription = title,
        equipmentCategory = category,
        equipmentBrand = brand,
        equipmentModel = model,
        status = RepairJobStatus.Requested,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = siteLocation,
        isAssignedToEngineer = false,
        engineerId = null,
        hospitalUserId = null,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )
}
