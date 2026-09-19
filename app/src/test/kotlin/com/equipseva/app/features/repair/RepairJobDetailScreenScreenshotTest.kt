package com.equipseva.app.features.repair

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.JobPayoutStatus
import com.equipseva.app.core.data.payouts.PayoutStatus
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.features.repair.RepairJobDetailViewModel.RepairJobDetailUiState
import com.equipseva.app.features.repair.RepairJobDetailViewModel.ViewerRole
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Pins the visual states of the repair-job detail screen as Roborazzi
 * goldens, rendered straight from a hand-built [RepairJobDetailUiState] so
 * no Hilt graph, Supabase client or lifecycle owner is involved.
 *
 * Every fixture job leaves `siteLatitude` / `siteLongitude` null: with
 * coordinates the location card mounts a Play-Services GoogleMap, which
 * Robolectric cannot render. Job and bid `createdAtInstant`s are null too,
 * because the bid card's "Placed 3d ago" caption and the unmatched-job
 * banner's age are derived from the wall clock and would drift the goldens
 * week over week. Signed photo URLs stay empty so no image fetch is
 * attempted. The equipment, issue, bids, escrow, payout and report cards
 * are all clock- and network-independent.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class RepairJobDetailScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/RepairJobDetailScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: RepairJobDetailUiState) {
        RepairJobDetailContent(
            state = state,
            actions = NoOpRepairJobDetailActions,
            onBack = {},
            onShowMessage = {},
            onOpenPayoutMethod = {},
            onBookAgain = {},
            onOpenDsr = { _, _ -> },
        )
    }

    @Test fun loading() = capture("loading") {
        Content(state = RepairJobDetailUiState(loading = true))
    }

    @Test fun not_found() = capture("not_found") {
        Content(state = RepairJobDetailUiState(loading = false, notFound = true))
    }

    @Test fun error() = capture("error") {
        Content(
            state = RepairJobDetailUiState(
                loading = false,
                errorMessage = "Couldn't load this job. Check your connection and try again.",
            ),
        )
    }

    // Hospital reviewing an open marketplace job: three competing bids with
    // different prices and ETAs; the third has no distance chip and the
    // second no note, so both optional rows are pinned in one frame.
    @Test fun hospital_open_bids() = capture("hospital_open_bids") {
        Content(
            state = hospitalState(
                job = job(status = RepairJobStatus.Requested),
                bids = listOf(
                    bid(
                        id = "bid-0001",
                        engineerUserId = RAVI_USER_ID,
                        amount = 4500.0,
                        etaHours = 4,
                        note = "Carry the C1-5 connector spare in stock; can swap it on the first visit.",
                        distanceKm = 3.2,
                    ),
                    bid(
                        id = "bid-0002",
                        engineerUserId = SURESH_USER_ID,
                        amount = 5200.0,
                        etaHours = 2,
                        note = null,
                        distanceKm = 7.8,
                    ),
                    bid(
                        id = "bid-0003",
                        engineerUserId = ANJALI_USER_ID,
                        amount = 3900.0,
                        etaHours = 24,
                        note = "Diagnostic visit first; parts quoted separately after inspection.",
                        distanceKm = null,
                    ),
                ),
            ),
        )
    }

    // Engineer who has already bid on an open job: "Your bid" card with the
    // withdraw action, address still hidden, bottom bar offers "Edit bid".
    @Test fun engineer_open_own_bid() = capture("engineer_open_own_bid") {
        val ownBid = bid(
            id = "bid-0001",
            engineerUserId = RAVI_USER_ID,
            amount = 4500.0,
            etaHours = 4,
            note = "Carry the C1-5 connector spare in stock; can swap it on the first visit.",
        )
        Content(
            state = engineerState(
                job = job(status = RepairJobStatus.Requested),
                ownBid = ownBid,
                bids = listOf(ownBid),
            ),
        )
    }

    // The assigned engineer on an Assigned job: address and "Navigate to
    // site" unlock, escrow is still awaiting the hospital's payment, and the
    // bottom bar shows the check-in CTA next to Cancel.
    @Test fun engineer_assigned() = capture("engineer_assigned") {
        val acceptedBid = bid(
            id = "bid-0001",
            engineerUserId = RAVI_USER_ID,
            amount = 4500.0,
            etaHours = 4,
            note = null,
            status = RepairBidStatus.Accepted,
        )
        Content(
            state = engineerState(
                job = job(
                    status = RepairJobStatus.Assigned,
                    engineerId = RAVI_ROW_ID,
                    contractedAmountRupees = 4500.0,
                ),
                ownBid = acceptedBid,
                bids = listOf(acceptedBid),
                escrow = escrow(status = "pending"),
            ),
        )
    }

    // Hospital view mid-repair: assigned-engineer card, funds held in
    // escrow, DSR entry visible, and no bottom-bar action for this side.
    @Test fun hospital_in_progress() = capture("hospital_in_progress") {
        Content(
            state = hospitalState(
                job = job(
                    status = RepairJobStatus.InProgress,
                    engineerId = RAVI_ROW_ID,
                    contractedAmountRupees = 4500.0,
                ),
                bids = decidedBids,
                escrow = escrow(status = "held", paidAt = "2026-09-15T10:15:00+00:00"),
            ),
        )
    }

    // Completed job from the hospital side: escrow released, payout
    // processed with a UTR, DSR + compliance report + GST invoice cards, and
    // the "Rate engineer" CTA because the hospital has not rated yet.
    @Test fun hospital_completed_escrow() = capture("hospital_completed_escrow") {
        Content(
            state = hospitalState(
                job = job(
                    status = RepairJobStatus.Completed,
                    engineerId = RAVI_ROW_ID,
                    contractedAmountRupees = 4500.0,
                    platformCommissionRupees = 315.0,
                    engineerPayoutRupees = 4185.0,
                ),
                bids = decidedBids,
                escrow = escrow(
                    status = "released",
                    paidAt = "2026-09-15T10:15:00+00:00",
                    releasedAt = "2026-09-15T18:40:00+00:00",
                ),
                payoutStatus = JobPayoutStatus(
                    id = "pay-00027",
                    amountPaise = 418_500L,
                    status = PayoutStatus.Processed,
                    mode = "UPI",
                    utr = "UTR426091600123",
                    failureReason = null,
                    destinationLabel = "ravi.kumar@okaxis",
                    engineerName = "Ravi Kumar",
                    queuedAt = "2026-09-15T18:40:00+00:00",
                    processedAt = "2026-09-15T18:44:00+00:00",
                ),
            ),
        )
    }

    // Cancelled job: the terminal banner replaces the stepper and the
    // bottom bar offers nothing.
    @Test fun cancelled() = capture("cancelled") {
        Content(
            state = hospitalState(
                job = job(
                    status = RepairJobStatus.Cancelled,
                    cancellationReason = "Vendor replaced the probe under the existing AMC; repair no longer needed.",
                ),
            ),
        )
    }

    // After accept_repair_bid the losing bids flip to Rejected; hospitals
    // still receive the full set, and the assigned-engineer card bridges
    // job.engineerId to a display name through the Accepted bid's user id.
    private val decidedBids: List<RepairBid> = listOf(
        bid(
            id = "bid-0001",
            engineerUserId = RAVI_USER_ID,
            amount = 4500.0,
            etaHours = 4,
            note = null,
            status = RepairBidStatus.Accepted,
        ),
        bid(
            id = "bid-0002",
            engineerUserId = SURESH_USER_ID,
            amount = 5200.0,
            etaHours = 2,
            note = null,
            status = RepairBidStatus.Rejected,
        ),
        bid(
            id = "bid-0003",
            engineerUserId = ANJALI_USER_ID,
            amount = 3900.0,
            etaHours = 24,
            note = null,
            status = RepairBidStatus.Rejected,
        ),
    )

    private fun hospitalState(
        job: RepairJob,
        bids: List<RepairBid> = emptyList(),
        escrow: RepairJobEscrowRepository.EscrowRow? = null,
        payoutStatus: JobPayoutStatus? = null,
    ): RepairJobDetailUiState = RepairJobDetailUiState(
        loading = false,
        job = job,
        viewerRole = ViewerRole.Hospital,
        bids = bids,
        engineerNames = ENGINEER_NAMES,
        hospitalName = HOSPITAL_NAME,
        hospitalLocation = HOSPITAL_LOCATION,
        escrow = escrow,
        payoutStatus = payoutStatus,
    )

    private fun engineerState(
        job: RepairJob,
        ownBid: RepairBid?,
        bids: List<RepairBid>,
        escrow: RepairJobEscrowRepository.EscrowRow? = null,
    ): RepairJobDetailUiState = RepairJobDetailUiState(
        loading = false,
        job = job,
        ownBid = ownBid,
        viewerRole = ViewerRole.Engineer,
        selfEngineerRowId = RAVI_ROW_ID,
        bids = bids,
        hospitalName = HOSPITAL_NAME,
        hospitalLocation = HOSPITAL_LOCATION,
        escrow = escrow,
    )

    private fun job(
        status: RepairJobStatus,
        engineerId: String? = null,
        contractedAmountRupees: Double? = null,
        platformCommissionRupees: Double? = null,
        engineerPayoutRupees: Double? = null,
        cancellationReason: String? = null,
    ): RepairJob = RepairJob(
        id = JOB_ID,
        jobNumber = "RPR-00027",
        title = "Ultrasound probe not detected",
        issueDescription = "Logiq P5 shows \"Probe not recognised\" for the C1-5 convex probe since Monday " +
            "morning. Other probes work on the same port. Connector pins look clean; no liquid damage visible.",
        equipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        equipmentBrand = "GE",
        equipmentModel = "Logiq P5",
        status = status,
        urgency = RepairJobUrgency.SameDay,
        estimatedCostRupees = 5000.0,
        contractedAmountRupees = contractedAmountRupees,
        scheduledDate = "2026-09-18",
        scheduledTimeSlot = "Morning (9am–12pm)",
        siteLocation = "Apollo Hospitals, Road No. 72, Jubilee Hills, Hyderabad 500033",
        siteLatitude = null,
        siteLongitude = null,
        isAssignedToEngineer = engineerId != null,
        engineerId = engineerId,
        hospitalUserId = HOSPITAL_USER_ID,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
        platformCommissionRupees = platformCommissionRupees,
        engineerPayoutRupees = engineerPayoutRupees,
        cancellationReason = cancellationReason,
    )

    private fun bid(
        id: String,
        engineerUserId: String,
        amount: Double,
        etaHours: Int?,
        note: String?,
        status: RepairBidStatus = RepairBidStatus.Pending,
        distanceKm: Double? = null,
    ): RepairBid = RepairBid(
        id = id,
        repairJobId = JOB_ID,
        engineerUserId = engineerUserId,
        amountRupees = amount,
        etaHours = etaHours,
        note = note,
        status = status,
        createdAtInstant = null,
        updatedAtInstant = null,
        distanceKm = distanceKm,
    )

    private fun escrow(
        status: String,
        paidAt: String? = null,
        releasedAt: String? = null,
    ): RepairJobEscrowRepository.EscrowRow = RepairJobEscrowRepository.EscrowRow(
        id = "esc-00027",
        status = status,
        amountRupees = 4500.0,
        paidAt = paidAt,
        releasedAt = releasedAt,
    )

    private companion object {
        const val JOB_ID = "job-00027"
        const val HOSPITAL_USER_ID = "hosp-user-0001"
        const val HOSPITAL_NAME = "Apollo Hospitals, Jubilee Hills"
        const val HOSPITAL_LOCATION = "Hyderabad, Telangana"
        // engineers.id (what job.engineerId points at) vs auth user id (what
        // bids and engineerNames are keyed by) are different ids in prod, so
        // the fixtures keep them distinct to exercise the same bridging.
        const val RAVI_ROW_ID = "eng-row-0007"
        const val RAVI_USER_ID = "eng-user-0007"
        const val SURESH_USER_ID = "eng-user-0012"
        const val ANJALI_USER_ID = "eng-user-0019"
        val ENGINEER_NAMES: Map<String, String> = mapOf(
            RAVI_USER_ID to "Ravi Kumar",
            SURESH_USER_ID to "Suresh Babu",
            ANJALI_USER_ID to "Anjali Menon",
        )
    }
}
