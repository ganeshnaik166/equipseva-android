package com.equipseva.app.features.earnings

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRow
import com.equipseva.app.core.data.payouts.PayoutStatus
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
 * Pins the four visual states of the engineer Earnings screen as Roborazzi
 * goldens.
 *
 * Fixtures deliberately leave `completedAtInstant` / `createdAtInstant` null:
 * the transaction time line is a relative "Paid 3d ago" derived from the wall
 * clock, so any fixed instant would drift the golden week over week. With
 * null instants the row falls back to the job status display name, which is
 * clock-independent. Escrow `nextReleaseAt` is safe — it renders as a fixed
 * IST calendar date, not a relative label.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class EarningsScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/EarningsScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: EarningsViewModel.UiState) {
        EarningsContent(
            state = state,
            onRefresh = {},
            onBack = {},
            onJobClick = {},
            onBankDetails = {},
            onBrowseJobs = {},
            onOpenActiveEscrows = {},
            onOpenEarningsProjection = {},
        )
    }

    @Test fun loading() = capture("loading") {
        Content(state = EarningsViewModel.UiState(loading = true, rows = emptyList()))
    }

    @Test fun empty() = capture("empty") {
        Content(
            state = EarningsViewModel.UiState(
                loading = false,
                rows = emptyList(),
                amcEarnings = emptyList(),
                payouts = emptyList(),
                payoutMethodVerified = true,
            ),
        )
    }

    @Test fun error() = capture("error") {
        Content(
            state = EarningsViewModel.UiState(
                loading = false,
                rows = emptyList(),
                payoutMethodVerified = true,
                errorMessage = "Couldn't load your earnings. Check your connection and try again.",
            ),
        )
    }

    @Test fun populated() = capture("populated") {
        val rows = listOf(
            earningRow(
                jobId = "RPR-00041",
                title = "Ventilator alarm not silencing",
                status = RepairJobStatus.Completed,
                bidAmount = 4500.0,
                commission = 450.0,
                payout = 4050.0,
            ),
            earningRow(
                jobId = "RPR-00038",
                title = "Patient monitor SpO2 sensor fault",
                status = RepairJobStatus.Completed,
                bidAmount = 2800.0,
                commission = 280.0,
                payout = 2520.0,
            ),
            earningRow(
                jobId = "RPR-00052",
                title = "Autoclave not reaching pressure",
                status = RepairJobStatus.InProgress,
                bidAmount = 3200.0,
                commission = null,
                payout = null,
            ),
            earningRow(
                jobId = "RPR-00055",
                title = "Dental chair hydraulic leak",
                status = RepairJobStatus.Assigned,
                bidAmount = 1800.0,
                commission = null,
                payout = null,
            ),
        )
        Content(
            state = EarningsViewModel.UiState(
                loading = false,
                paidTotal = 6570.0,
                pendingTotal = 5000.0,
                rows = rows,
                escrowSummary = RepairJobEscrowRepository.EngineerEscrowSummary(
                    totalHeldRupees = 3200.0,
                    countHeld = 1,
                    nextReleaseAt = "2026-03-14T09:30:00Z",
                    totalReleased30d = 6570.0,
                    countInDispute = 0,
                    countPendingPayment = 1,
                ),
                payouts = listOf(
                    payoutRow(
                        id = "PAY-00012",
                        jobNumber = "RPR-00041",
                        amountPaise = 405_000L,
                        status = PayoutStatus.Processed,
                        utr = "HDFCR52026031412345",
                        failureReason = null,
                    ),
                    payoutRow(
                        id = "PAY-00011",
                        jobNumber = "RPR-00038",
                        amountPaise = 252_000L,
                        status = PayoutStatus.Failed,
                        utr = null,
                        failureReason = "Beneficiary VPA is invalid",
                    ),
                ),
                payoutMethodVerified = true,
                payoutMethodExists = true,
            ),
        )
    }

    private fun earningRow(
        jobId: String,
        title: String,
        status: RepairJobStatus,
        bidAmount: Double,
        commission: Double?,
        payout: Double?,
    ): EarningsViewModel.EarningRow = EarningsViewModel.EarningRow(
        bid = RepairBid(
            id = "BID-$jobId",
            repairJobId = jobId,
            engineerUserId = "ENG-00007",
            amountRupees = bidAmount,
            etaHours = 4,
            note = null,
            status = RepairBidStatus.Accepted,
            createdAtInstant = null,
            updatedAtInstant = null,
        ),
        job = RepairJob(
            id = jobId,
            jobNumber = jobId,
            title = title,
            issueDescription = title,
            equipmentCategory = RepairEquipmentCategory.PatientMonitoring,
            equipmentBrand = "Philips",
            equipmentModel = "IntelliVue MX450",
            status = status,
            urgency = RepairJobUrgency.Scheduled,
            estimatedCostRupees = bidAmount,
            scheduledDate = null,
            scheduledTimeSlot = null,
            siteLocation = "Apollo Hospital, Hyderabad",
            isAssignedToEngineer = true,
            engineerId = "ENG-00007",
            hospitalUserId = "HOSP-00003",
            startedAtInstant = null,
            completedAtInstant = null,
            hospitalRating = null,
            hospitalReview = null,
            engineerRating = null,
            engineerReview = null,
            createdAtInstant = null,
            updatedAtInstant = null,
            platformCommissionRupees = commission,
            engineerPayoutRupees = payout,
        ),
    )

    private fun payoutRow(
        id: String,
        jobNumber: String,
        amountPaise: Long,
        status: PayoutStatus,
        utr: String?,
        failureReason: String?,
    ): EngineerPayoutRow = EngineerPayoutRow(
        id = id,
        jobNumber = jobNumber,
        amountPaise = amountPaise,
        status = status,
        mode = "UPI",
        utr = utr,
        failureReason = failureReason,
        destinationLabel = "ravi.kumar@okhdfcbank",
        queuedAt = "2026-03-12T08:00:00Z",
        processedAt = if (status == PayoutStatus.Processed) "2026-03-12T08:05:00Z" else null,
    )
}
