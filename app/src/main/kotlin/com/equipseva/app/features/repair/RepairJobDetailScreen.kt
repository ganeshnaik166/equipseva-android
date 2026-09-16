package com.equipseva.app.features.repair

import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.HelpSupportSheet
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.features.repair.detail.sections.AssignedEngineerCard
import com.equipseva.app.features.repair.detail.sections.BidsList
import com.equipseva.app.features.repair.detail.sections.CompletionProofCard
import com.equipseva.app.features.repair.detail.sections.DsrEntryCard
import com.equipseva.app.features.repair.detail.sections.EngineerPayoutStatusCard
import com.equipseva.app.features.repair.detail.sections.EquipmentCard
import com.equipseva.app.features.repair.detail.sections.ErrorState
import com.equipseva.app.features.repair.detail.sections.EscrowMissingPlaceholderCard
import com.equipseva.app.features.repair.detail.sections.EscrowStatusCard
import com.equipseva.app.features.repair.detail.sections.HospitalBanner
import com.equipseva.app.features.repair.detail.sections.InvoiceDownloadCard
import com.equipseva.app.features.repair.detail.sections.IssueCard
import com.equipseva.app.features.repair.detail.sections.LocationCard
import com.equipseva.app.features.repair.detail.sections.NoBidsYetCard
import com.equipseva.app.features.repair.detail.sections.NotFoundState
import com.equipseva.app.features.repair.detail.sections.QueuedOutboxPill
import com.equipseva.app.features.repair.detail.sections.ServiceReportCard
import com.equipseva.app.features.repair.detail.sections.StatusStepperRow
import com.equipseva.app.features.repair.detail.sections.StickyBottomBar
import com.equipseva.app.features.repair.detail.sections.TerminalStatusBanner
import com.equipseva.app.features.repair.detail.sections.WarrantyBanner
import com.equipseva.app.features.repair.detail.sections.YourBidCard
import com.equipseva.app.features.repair.detail.sheets.BidComposerSheet
import com.equipseva.app.features.repair.detail.sheets.CancelSheet
import com.equipseva.app.features.repair.detail.sheets.CheckinSheet
import com.equipseva.app.features.repair.detail.sheets.CompletionProofSheet
import com.equipseva.app.features.repair.detail.sheets.EngineerResponseSheet
import com.equipseva.app.features.repair.detail.sheets.EscrowDisputeSheet
import com.equipseva.app.features.repair.detail.sheets.RateSheet

internal val WarnGold = Color(0xFFF5A623)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onOpenChat: (String) -> Unit,
    // Round 437 fix #2 — engineer self-recovery path from a Failed
    // payout shown on this screen. Defaults to no-op; the caller in
    // MainNavGraph wires it to Routes.ENGINEER_PAYOUT_METHOD when
    // navigating from the engineer hub.
    onOpenPayoutMethod: () -> Unit = {},
    // v0.3.5 fix #9 — Book-again CTA wiring. On a completed job, the
    // hospital can tap "Book this engineer again" in the bottom bar
    // to start a fresh booking form pre-filled with this engineer's
    // id (route arg → RequestServiceViewModel.loadEngineerReassurance).
    // Default no-op so existing callsites compile; MainNavGraph
    // overrides with the actual navController.navigate call.
    onBookAgain: (engineerId: String) -> Unit = {},
    // round3812 — Digital Service Report entry (round494 backend, first
    // client). The screen passes the job id and its own viewer-role flag;
    // MainNavGraph turns them into the DSR route.
    onOpenDsr: (jobId: String, isHospital: Boolean) -> Unit = { _, _ -> },
    viewModel: RepairJobDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Round 426 — re-fetch on return so new bids / status flips / cost-
    // revision outcomes that landed while the user was in chat or picker
    // surfaces refresh instead of showing stale data. The viewmodel only
    // subscribes to outbox counters + pending cost-revision realtime;
    // bids and job-row updates require an explicit fetch.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.retry() }

    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
    }
    val context = LocalContext.current
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is RepairJobDetailViewModel.Effect.NavigateToChat -> onOpenChat(effect.conversationId)
                // PR-D3: hand the signed report URL to the system browser.
                // Chrome / WebView render the HTML with photos and the
                // user can use the print menu to save as PDF if needed.
                is RepairJobDetailViewModel.Effect.OpenServiceReport -> {
                    val intent = Intent(Intent.ACTION_VIEW, effect.url.toUri()).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
                // Round 449: same browser-handoff for the GST tax
                // invoice. Hospital uses the print menu to save as PDF.
                is RepairJobDetailViewModel.Effect.OpenInvoice -> {
                    val intent = Intent(Intent.ACTION_VIEW, effect.url.toUri()).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
            }
        }
    }

    val actions = remember(viewModel) { viewModel.asActions() }
    RepairJobDetailContent(
        state = state,
        actions = actions,
        onBack = onBack,
        onShowMessage = onShowMessage,
        onOpenPayoutMethod = onOpenPayoutMethod,
        onBookAgain = onBookAgain,
        onOpenDsr = onOpenDsr,
    )
}

/**
 * Stateless body of the repair-job detail screen. Kept ViewModel-free so
 * screenshot fixtures and previews can pin each visual state without Hilt
 * or a lifecycle owner. The wrapper above owns the one-shot effects
 * (snackbars, chat navigation, browser hand-offs) because those need the
 * ViewModel's flows; everything drawn on screen lives here.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun RepairJobDetailContent(
    state: RepairJobDetailViewModel.RepairJobDetailUiState,
    actions: RepairJobDetailActions,
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onOpenPayoutMethod: () -> Unit,
    onBookAgain: (engineerId: String) -> Unit,
    onOpenDsr: (jobId: String, isHospital: Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    var withdrawConfirmOpen by rememberSaveable { mutableStateOf(false) }
    var checkinSheetOpen by rememberSaveable { mutableStateOf(false) }
    var cancelSheetOpen by rememberSaveable { mutableStateOf(false) }
    var rateSheetOpen by rememberSaveable { mutableStateOf(false) }
    // FIX #10 — Help & Support escalation sheet, opened from the '?'
    // icon in the top bar. Passes jobNumber so the report-form mailto
    // subject is pre-tagged with the public job ref.
    var helpSheetOpen by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier,
        containerColor = PaperDefault,
        topBar = {
            EsTopBar(
                title = state.job?.jobNumber ?: "Repair request",
                subtitle = state.job?.equipmentLabel,
                onBack = onBack,
                right = {
                    // FIX #10: Help (?) icon + optional Report menu. Both
                    // live in the EsTopBar `right` slot — the Row lets
                    // them coexist when canReport=true, otherwise the
                    // help icon stands alone.
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(Color.Transparent)
                                .clickable(
                                    onClickLabel = "Open help and support",
                                    role = androidx.compose.ui.semantics.Role.Button,
                                    onClick = { helpSheetOpen = true },
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Outlined.HelpOutline,
                                contentDescription = null,
                                tint = SevaInk700,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                        if (state.canReport) {
                            var menuOpen by rememberSaveable { mutableStateOf(false) }
                            Box {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(Color.Transparent)
                                        .clickable { menuOpen = true },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(
                                        imageVector = Icons.Filled.MoreVert,
                                        contentDescription = "More",
                                        tint = SevaInk700,
                                        modifier = Modifier.size(18.dp),
                                    )
                                }
                                DropdownMenu(
                                    expanded = menuOpen,
                                    onDismissRequest = { menuOpen = false },
                                ) {
                                    DropdownMenuItem(
                                        text = { Text(stringResource(R.string.repair_detail_report_job)) },
                                        onClick = {
                                            menuOpen = false
                                            actions.onOpenReport()
                                        },
                                    )
                                }
                            }
                        }
                    }
                },
            )
        },
        bottomBar = {
            val job = state.job
            if (job != null) {
                StickyBottomBar(
                    job = job,
                    ownBid = state.ownBid,
                    selfEngineerRowId = state.selfEngineerRowId,
                    viewerRole = state.viewerRole,
                    updatingStatus = state.updatingStatus,
                    queuedStatusCount = state.queuedStatusCount,
                    pendingCostRevision = state.pendingCostRevision,
                    onPlaceBid = actions::openBidComposer,
                    onCheckIn = { checkinSheetOpen = true },
                    onMarkDone = actions::openProofSheet,
                    onRate = { rateSheetOpen = true },
                    onCancel = { cancelSheetOpen = true },
                    onReviseQuote = actions::openReviseQuoteSheet,
                    onBookAgain = onBookAgain,
                )
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            QueuedOutboxPill(
                bidCount = state.queuedBidCount,
                statusCount = state.queuedStatusCount,
            )
            // v2 — hospital-only revised-quote banner. Tap → decision sheet.
            // Engineer side sees "awaiting hospital approval" copy below.
            val pendingRev = state.pendingCostRevision
            if (pendingRev != null) {
                when (state.viewerRole) {
                    RepairJobDetailViewModel.ViewerRole.Hospital ->
                        com.equipseva.app.features.repair.components.CostRevisionBanner(
                            revision = pendingRev,
                            onTap = actions::openRevisionDecisionSheet,
                        )
                    RepairJobDetailViewModel.ViewerRole.Engineer ->
                        com.equipseva.app.features.repair.components.CostRevisionBanner(
                            revision = pendingRev,
                            onTap = {}, // engineer view is informational only
                        )
                    else -> Unit
                }
            }
            // r785 — hospital "0 bids in 7d" banner. Closes the founder
            // /unmatched-jobs (r661) loop by surfacing the same signal to
            // the hospital that posted the job. They can adjust price /
            // refine description without the founder having to outreach.
            run {
                val job = state.job
                if (job != null) {
                    val daysOld = job.createdAtInstant?.let {
                        java.time.Duration.between(it, java.time.Instant.now()).toDays()
                    } ?: 0L
                    if (
                        shouldShowUnmatchedJobBanner(
                            isHospital = state.viewerRole ==
                                RepairJobDetailViewModel.ViewerRole.Hospital,
                            status = job.status,
                            engineerId = job.engineerId,
                            hasBids = state.bids.isNotEmpty(),
                            daysOld = daysOld,
                        )
                    ) {
                        com.equipseva.app.features.repair.components.UnmatchedJobBanner(
                            daysOld = daysOld,
                        )
                    }
                }
            }
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
                state.notFound -> NotFoundState(onBack)
                state.job == null && state.errorMessage != null -> ErrorState(
                    message = state.errorMessage,
                    onRetry = actions::retry,
                )
                state.job != null -> JobBody(
                    job = state.job,
                    ownBid = state.ownBid,
                    bids = state.bids,
                    engineerNames = state.engineerNames,
                    hospitalName = state.hospitalName,
                    hospitalLocation = state.hospitalLocation,
                    viewerRole = state.viewerRole,
                    acceptingBidId = state.acceptingBidId,
                    openingChat = state.openingChat,
                    afterPhotoSignedUrls = state.afterPhotoSignedUrls,
                    issuePhotoSignedUrls = state.issuePhotoSignedUrls,
                    generatingServiceReport = state.generatingServiceReport,
                    generatingInvoice = state.generatingInvoice,
                    escrow = state.escrow,
                    payoutStatus = state.payoutStatus,
                    confirmingEscrowRelease = state.confirmingEscrowRelease,
                    onMessageEngineer = actions::openChatWithEngineer,
                    onMessageHospital = actions::openChatWithHospital,
                    onAcceptBid = actions::acceptBid,
                    onWithdraw = { withdrawConfirmOpen = true },
                    onDownloadReport = actions::generateServiceReport,
                    onDownloadInvoice = actions::generateInvoice,
                    onPayEscrow = actions::openEscrowPaymentSheet,
                    onConfirmEscrowRelease = actions::confirmEscrowRelease,
                    onOpenEscrowDispute = actions::openEscrowDisputeSheet,
                    onOpenEngineerResponseSheet = actions::openEngineerResponseSheet,
                    onOpenPayoutMethod = onOpenPayoutMethod,
                    onOpenDsr = onOpenDsr,
                )
            }
        }
    }

    if (state.bidComposerOpen && state.job != null) {
        BidComposerSheet(
            existingBid = state.ownBid?.takeIf { it.status == RepairBidStatus.Pending },
            placingBid = state.placingBid,
            onDismiss = actions::closeBidComposer,
            onSubmit = actions::submitBid,
        )
    }

    if (state.proofSheetOpen && state.job != null) {
        CompletionProofSheet(
            submitting = state.submittingProof,
            onDismiss = actions::closeProofSheet,
            onSubmit = actions::submitCompletionProof,
        )
    }

    if (checkinSheetOpen) {
        CheckinSheet(
            updating = state.updatingStatus,
            onDismiss = { if (!state.updatingStatus) checkinSheetOpen = false },
            onConfirm = { photos ->
                checkinSheetOpen = false
                actions.submitCheckinWithProof(photos)
            },
        )
    }

    if (cancelSheetOpen) {
        // Plumb job status + escrow facts into the sheet so the warning
        // copy adapts to the consequences of the cancellation (engineer
        // en route? funds in escrow? both?). A bland one-liner on an
        // already-assigned job with money held had hospitals second-
        // guessing themselves and reading vague support questions.
        CancelSheet(
            updating = state.updatingStatus,
            jobStatus = state.job?.status,
            escrowHeldRupees = state.escrow?.takeIf { it.isHeld }?.amountRupees?.toInt(),
            onDismiss = { if (!state.updatingStatus) cancelSheetOpen = false },
            onConfirm = { reason ->
                cancelSheetOpen = false
                actions.cancelJob(reason = reason)
            },
        )
    }

    if (rateSheetOpen) {
        val job = state.job
        if (job != null) {
            RateSheet(
                job = job,
                viewerRole = state.viewerRole,
                submitting = state.submittingRating,
                onDismiss = { if (!state.submittingRating) rateSheetOpen = false },
                onSubmit = { stars, note ->
                    actions.submitRating(stars, note)
                    rateSheetOpen = false
                },
            )
        }
    }

    if (state.reviseQuoteSheetOpen) {
        val current = state.job?.contractedAmountRupees
        if (current != null) {
            com.equipseva.app.features.repair.components.ReviseQuoteSheet(
                currentContractedRupees = current,
                submitting = state.proposingRevision,
                onDismiss = actions::closeReviseQuoteSheet,
                onSubmit = { amount, reason -> actions.proposeCostRevision(amount, reason) },
            )
        }
    }

    if (state.revisionDecisionSheetOpen) {
        val rev = state.pendingCostRevision
        if (rev != null) {
            com.equipseva.app.features.repair.components.CostRevisionDecisionSheet(
                revision = rev,
                deciding = state.decidingRevision,
                onDismiss = actions::closeRevisionDecisionSheet,
                onDecide = { approve -> actions.decideCostRevision(approve) },
            )
        }
    }

    if (state.reportingTargetId != null) {
        ReportContentSheet(
            titleLabel = "Report this repair job",
            submitting = state.submittingReport,
            onDismiss = actions::onDismissReport,
            onSubmit = actions::onSubmitReport,
        )
    }

    // FIX #10 — Help & Support sheet. repairJobNumber is plumbed in so
    // 'Report engineer' / 'Report job issue' mailto subjects carry the
    // public job ref (e.g. "Job issue — RPR-00027"), saving support
    // from a round-trip asking which job the user means.
    if (helpSheetOpen) {
        HelpSupportSheet(
            onClose = { helpSheetOpen = false },
            onShowMessage = onShowMessage,
            repairJobNumber = state.job?.jobNumber,
        )
    }

    // v0.3.4 PR C — pre-checkout order summary sheet. Renders BEFORE
    // the Razorpay sheet so the hospital can review engineer + scope
    // + bid + GST + total + escrow assurance, then taps "Pay ₹X"
    // (which closes this sheet and opens JobEscrowPaymentSheet).
    if (state.orderSummarySheetOpen && state.job != null && state.selectedBidForSummary != null) {
        val bid = state.selectedBidForSummary
        val engineerName = state.engineerNames[bid.engineerUserId] ?: "the engineer"
        OrderSummarySheet(
            job = state.job,
            bid = bid,
            engineerName = engineerName,
            onClose = actions::closeOrderSummarySheet,
            onProceedToPayment = actions::proceedToPaymentFromSummary,
        )
    }

    // PR-D5: per-job escrow pay-in.
    val escrow = state.escrow
    if (state.escrowPaymentSheetOpen && state.job != null && escrow != null) {
        // Engineer name comes from the accepted bid's engineer profile.
        val engineerName = run {
            val acceptedEngineerUserId = state.bids.firstOrNull {
                it.status == RepairBidStatus.Accepted
            }?.engineerUserId
            acceptedEngineerUserId?.let { state.engineerNames[it] } ?: "the engineer"
        }
        JobEscrowPaymentSheet(
            repairJobId = state.job.id,
            amountRupees = escrow.amountRupees,
            engineerName = engineerName,
            onClose = actions::closeEscrowPaymentSheet,
            onShowMessage = onShowMessage,
            onCompleted = actions::refreshEscrow,
        )
    }

    // PR-D5: hospital opens a dispute (within 48h post-completion).
    if (state.escrowDisputeSheetOpen) {
        EscrowDisputeSheet(
            submitting = state.openingEscrowDispute,
            onDismiss = actions::closeEscrowDisputeSheet,
            onSubmit = actions::openEscrowDispute,
        )
    }

    // PR-D29: engineer responds to a hospital's dispute.
    if (state.engineerResponseSheetOpen) {
        EngineerResponseSheet(
            submitting = state.submittingEngineerResponse,
            onDismiss = actions::closeEngineerResponseSheet,
            onSubmit = actions::submitEngineerResponse,
        )
    }

    if (withdrawConfirmOpen) {
        AlertDialog(
            onDismissRequest = {
                if (!state.withdrawingBid) withdrawConfirmOpen = false
            },
            title = { Text(stringResource(R.string.repair_detail_withdraw_dialog_title)) },
            text = { Text(stringResource(R.string.repair_detail_withdraw_dialog_body)) },
            confirmButton = {
                TextButton(
                    enabled = !state.withdrawingBid,
                    onClick = {
                        withdrawConfirmOpen = false
                        actions.withdrawBid()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) { Text(stringResource(R.string.repair_detail_withdraw_confirm)) }
            },
            dismissButton = {
                TextButton(
                    enabled = !state.withdrawingBid,
                    onClick = { withdrawConfirmOpen = false },
                ) { Text(stringResource(R.string.repair_detail_keep_bid)) }
            },
        )
    }
}

@Composable
private fun JobBody(
    job: RepairJob,
    ownBid: RepairBid?,
    bids: List<RepairBid>,
    engineerNames: Map<String, String>,
    hospitalName: String?,
    hospitalLocation: String?,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    acceptingBidId: String?,
    openingChat: Boolean,
    afterPhotoSignedUrls: List<String>,
    issuePhotoSignedUrls: List<String>,
    generatingServiceReport: Boolean,
    generatingInvoice: Boolean,
    escrow: com.equipseva.app.core.data.escrow.RepairJobEscrowRepository.EscrowRow?,
    payoutStatus: com.equipseva.app.core.data.payouts.JobPayoutStatus?,
    confirmingEscrowRelease: Boolean,
    onMessageEngineer: () -> Unit,
    onMessageHospital: () -> Unit,
    onAcceptBid: (String) -> Unit,
    onWithdraw: () -> Unit,
    onDownloadReport: () -> Unit,
    onDownloadInvoice: () -> Unit,
    onPayEscrow: () -> Unit,
    onConfirmEscrowRelease: () -> Unit,
    onOpenEscrowDispute: () -> Unit,
    onOpenEngineerResponseSheet: () -> Unit,
    onOpenPayoutMethod: () -> Unit = {},
    onOpenDsr: (jobId: String, isHospital: Boolean) -> Unit = { _, _ -> },
) {
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hospital banner — site name + verified + location + urgency.
        HospitalBanner(
            siteName = hospitalName ?: "Hospital",
            siteCity = hospitalLocation,
            urgency = job.urgency,
        )

        // Status stepper — 5 step linear timeline. Replaced by a
        // terminal-state banner when the job is no longer progressing
        // through the normal flow (Cancelled / Disputed). Without this,
        // the stepper sits at "Requested" forever on cancelled jobs
        // and gives no visual signal that the job is closed.
        val terminal = terminalStatusBannerCopy(job.status, job.cancellationReason)
        if (terminal != null) {
            TerminalStatusBanner(title = terminal.title, subtitle = terminal.subtitle)
        } else {
            StatusStepperRow(currentStatus = job.status)
        }

        // PR-D9 + PR-D12 — 30-day warranty banner. Server stamped this
        // on insert (find_warranty_source_job matched a recent
        // completed job for the same equipment); PR-D12 will zero the
        // engineer-side commission on completion. Surfaces as a soft
        // banner so the hospital sees the promise + the engineer sees
        // why the platform is covering them.
        if (job.isWarrantyCovered) {
            WarrantyBanner()
        }

        EsSection(title = "Equipment") {
            EquipmentCard(job = job)
        }

        EsSection(title = "Issue") {
            IssueCard(job = job, issuePhotoUrls = issuePhotoSignedUrls)
        }

        // Assigned engineer (only if engineer is assigned + viewer is hospital).
        if (job.engineerId != null && isHospital) {
            // engineerNames is keyed by engineer **user_id** (auth.uid) — but
            // job.engineerId points at the engineers row id. Pull the
            // accepted bid's engineerUserId to bridge the two so the card
            // shows "Ravi Kumar" instead of the generic "Engineer" fallback.
            val acceptedEngineerUserId = bids.firstOrNull {
                it.status == com.equipseva.app.core.data.repair.RepairBidStatus.Accepted
            }?.engineerUserId
            val engineerName = acceptedEngineerUserId?.let { engineerNames[it] } ?: "Engineer"
            EsSection(title = "Assigned engineer") {
                AssignedEngineerCard(
                    name = engineerName,
                    openingChat = openingChat,
                    onMessage = onMessageEngineer,
                )
            }
        }

        // Bids — hospital + status==requested + genuinely OPEN (unassigned).
        // Same reason as the UnmatchedJobBanner (r1482): an AMC maintenance
        // visit is Requested but pre-assigned (engineerId != null) and never
        // bid on, so the "No bids yet — engineers usually bid within 5–30 min"
        // card would contradict the "Assigned engineer" section shown above.
        if (shouldShowBidsSection(isHospital, job.status, job.engineerId)) {
            if (bids.isNotEmpty()) {
                EsSection(title = "Bids (${bids.size})") {
                    BidsList(
                        bids = bids,
                        engineerNames = engineerNames,
                        acceptingBidId = acceptingBidId,
                        openingChat = openingChat,
                        onAccept = onAcceptBid,
                        onMessage = onMessageEngineer,
                    )
                }
            } else {
                EsSection(title = "Bids") {
                    NoBidsYetCard()
                }
            }
        }

        // Engineer-side: own bid quick view (when not requested or own bid present).
        if (!isHospital && ownBid != null) {
            EsSection(title = "Your bid") {
                YourBidCard(ownBid = ownBid, onWithdraw = onWithdraw)
            }
        }

        EsSection(title = "Location") {
            LocationCard(job = job, viewerRole = viewerRole)
        }

        if (job.status == RepairJobStatus.Completed && afterPhotoSignedUrls.isNotEmpty()) {
            EsSection(title = "Completion proof") {
                CompletionProofCard(urls = afterPhotoSignedUrls)
            }
        }

        // PR-D5: per-job escrow status + actions.
        // PR #1033 restored the escrow-INSERT in accept_repair_bid;
        // every assigned-or-later job should have an escrow row. The
        // placeholder branch below is defensive: any future migration
        // that drops the insert (or a partial-failure race) leaves
        // the hospital staring at a job stuck at "Assigned" with no
        // Pay button and no idea what to do. Surface the missing-
        // escrow state explicitly + give the user a recovery path
        // (pull-to-refresh / contact support) instead of an invisible
        // dead-end.
        val needsEscrow = job.status in setOf(
            RepairJobStatus.Assigned,
            RepairJobStatus.EnRoute,
            RepairJobStatus.InProgress,
            RepairJobStatus.Completed,
        )
        when {
            escrow != null -> {
                EsSection(title = "Escrow") {
                    EscrowStatusCard(
                        escrow = escrow,
                        isHospital = isHospital,
                        isJobCompleted = job.status == RepairJobStatus.Completed,
                        confirmingRelease = confirmingEscrowRelease,
                        // Round 437 fix #5 — downgrade card copy
                        // when escrow=released but the downstream
                        // engineer payout has Failed / Cancelled,
                        // so the card doesn't read "Released to
                        // engineer" while the next card right below
                        // says the engineer never actually got paid.
                        payoutFailed = payoutStatus != null && (
                            payoutStatus.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed ||
                                payoutStatus.status == com.equipseva.app.core.data.payouts.PayoutStatus.Cancelled
                        ),
                        onPay = onPayEscrow,
                        onConfirmRelease = onConfirmEscrowRelease,
                        onOpenDispute = onOpenEscrowDispute,
                        onOpenEngineerResponse = onOpenEngineerResponseSheet,
                    )
                }
            }
            needsEscrow -> {
                EsSection(title = "Escrow") {
                    EscrowMissingPlaceholderCard()
                }
            }
            else -> Unit
        }

        // Round 431 — engineer payout status. Surfaces once the
        // escrow trigger has enqueued a row (i.e. escrow.status ==
        // 'released'). Both hospital and engineer see it so the
        // platform's role in the money movement is legible to both
        // sides.
        payoutStatus?.let { p ->
            EsSection(title = "Engineer payout") {
                EngineerPayoutStatusCard(
                    p = p,
                    isHospital = isHospital,
                    // Round 437 fix #2 — engineer-side recovery CTA
                    // when their own payout has failed. Hospital
                    // can't fix the engineer's UPI so we don't
                    // expose it to them.
                    onOpenPayoutMethod = if (!isHospital) onOpenPayoutMethod else null,
                )
            }
        }

        // PR-D3: compliance audit-trail HTML report. Available to both
        // sides on Completed jobs — hospital saves it for NABH/JCI
        // archives, engineer keeps it as proof of work delivered.
        // round3812 — the Digital Service Report is the PRIMARY compliance
        // record (IEC 62353 verdict, calibration, work summary, hospital
        // countersignature); the HTML "Compliance report" below is the
        // derived artifact. Engineer files it; hospital reviews and signs.
        // Backed by round494 RPCs that had zero clients until now — which
        // is why the PM calendar and NABH bundle were structurally empty.
        // Shown from IN PROGRESS onward, not Completed-only: the natural
        // filing moment is while wrapping up on-site, and submit_dsr
        // itself gates on the accepted bid, not on job status.
        if (job.engineerId != null &&
            (job.status == RepairJobStatus.InProgress || job.status == RepairJobStatus.Completed)
        ) {
            EsSection(title = "Service report (DSR)") {
                DsrEntryCard(
                    isHospital = isHospital,
                    onOpen = { onOpenDsr(job.id, isHospital) },
                )
            }
        }

        if (job.status == RepairJobStatus.Completed) {
            EsSection(title = "Compliance report") {
                ServiceReportCard(
                    loading = generatingServiceReport,
                    onDownload = onDownloadReport,
                )
            }

            // Round 449 — GST tax invoice. Available to both sides;
            // hospitals download for their accounting / ITC claim,
            // engineers / founder see the same surface for audit.
            EsSection(title = "GST tax invoice") {
                InvoiceDownloadCard(
                    loading = generatingInvoice,
                    onDownload = onDownloadInvoice,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
    }
}

// --- Status stepper ---------------------------------------------------------
internal val StepLabels = listOf("Requested", "Assigned", "En route", "In progress", "Completed")
internal val StepStatuses = listOf(
    RepairJobStatus.Requested,
    RepairJobStatus.Assigned,
    RepairJobStatus.EnRoute,
    RepairJobStatus.InProgress,
    RepairJobStatus.Completed,
)

/**
 * Index of [currentStatus] in the [StepStatuses] timeline, or -1 when
 * the status isn't part of the stepper at all (Cancelled, Disputed,
 * Unknown). Extracted so the index-to-dot rendering logic can be
 * unit-tested without the Compose runtime.
 */
internal fun statusStepIndex(currentStatus: RepairJobStatus): Int =
    StepStatuses.indexOf(currentStatus).let { if (it < 0) -1 else it }

// --- Misc helpers -----------------------------------------------------------

internal fun initialsOf(name: String): String = repairDetailInitials(name)

/**
 * Initials for a counterparty avatar on the repair-job detail screen.
 * Differs from the canonical [com.equipseva.app.core.util.initialsOf]
 * in one specific way: a single-token name uses the first TWO chars
 * (so "Priyanka" → "Pr") rather than first-letter only ("P"). Pinned
 * top-level so the divergence is unit-testable and a future merge
 * with the canonical helper would have to be intentional.
 */
internal fun repairDetailInitials(name: String): String {
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    return when {
        parts.isEmpty() -> "?"
        parts.size == 1 -> parts[0].take(2)
        else -> "${parts[0].first()}${parts[1].first()}"
    }
}

internal val UriListSaver = androidx.compose.runtime.saveable.listSaver<List<Uri>, String>(
    save = { it.map(Uri::toString) },
    restore = { it.map(Uri::parse) },
)

/**
 * Render a nullable / possibly-blank text field as either its
 * content or the em-dash placeholder (U+2014). Pin so a refactor
 * that swapped to ASCII "-" surfaces.
 */
internal fun textOrDash(value: String?): String =
    value?.takeIf { it.isNotBlank() } ?: "—"

/**
 * Compose the schedule line on EquipmentCard's "Schedule" row.
 *
 *   * date + slot → "2026-05-22 morning"
 *   * date only → "2026-05-22"
 *   * slot only → "morning"
 *   * neither / blank → "—"
 *
 * Joined with a single space; blank parts dropped. Pin so a refactor
 * doesn't leave a trailing/leading space when one side is missing.
 */
internal fun equipmentScheduleLine(scheduledDate: String?, scheduledTimeSlot: String?): String =
    listOfNotNull(
        scheduledDate?.takeIf { it.isNotBlank() },
        scheduledTimeSlot?.takeIf { it.isNotBlank() },
    ).joinToString(" ").ifBlank { "—" }

/**
 * Banner copy for the terminal-status replacement of the status
 * stepper. Returns null when the job is still progressing through
 * the normal flow (the caller renders the stepper instead).
 *
 *   * Cancelled → "Job cancelled" + admin-provided reason (or generic
 *     "No further action needed" if reason is null/blank).
 *   * Disputed → "Job in dispute" + canned subtitle.
 *   * Anything else → null.
 *
 * Pinned: the reason prefix is "Reason: " (with colon + space) — a
 * refactor that dropped the prefix would surface the bare admin
 * sentence as if it were the engineer's own copy.
 */
internal data class TerminalStatusCopy(val title: String, val subtitle: String)

internal fun terminalStatusBannerCopy(
    status: RepairJobStatus,
    cancellationReason: String?,
): TerminalStatusCopy? = when (status) {
    RepairJobStatus.Cancelled -> TerminalStatusCopy(
        title = "Job cancelled",
        subtitle = cancellationReason?.takeIf { it.isNotBlank() }
            ?.let { "Reason: $it" }
            ?: "No further action needed.",
    )
    RepairJobStatus.Disputed -> TerminalStatusCopy(
        title = "Job in dispute",
        // Old copy ("Our team will reach out once a decision is made")
        // left the engineer passive at the worst possible moment — they
        // have one chance to add photos + context BEFORE admin decides.
        // Point both sides at the Escrow section's "Respond" CTA below.
        subtitle = "Add photos and context in the Escrow section below before admin decides. Both sides can respond.",
    )
    else -> null
}

/**
 * Label + subtitle copy on the escrow status card on RepairJobDetail.
 *
 * Five user-visible states + a generic fallback for any future
 * status that isn't yet wired. The Released state branches on
 * [isHospital] — engineer reads the same card, so third-person
 * "to engineer" is jarring on their view. Pin the role-aware split
 * so a refactor doesn't lose it.
 *
 * Pinned regions:
 *   * 48-hour auto-release callout on Held (a load-bearing UX promise)
 *   * "to engineer" vs "to you" branching on Released
 *   * Fallback "Escrow ${status}" surfaces an unknown server-side
 *     state literally rather than crashing or showing blank
 */
internal data class EscrowStatusCopy(val label: String, val subtitle: String)

internal fun escrowStatusCardCopy(
    escrow: com.equipseva.app.core.data.escrow.RepairJobEscrowRepository.EscrowRow,
    isHospital: Boolean,
    // Round 437 fix #5 — true when escrow.isReleased is true on the
    // server-side but the downstream engineer-payout row is Failed
    // or Cancelled. Without this branch the card reads "Released to
    // engineer" while the EngineerPayoutStatusCard right below shows
    // "Payout failed" — contradictory.
    payoutFailed: Boolean = false,
): EscrowStatusCopy = when {
    escrow.isPending -> EscrowStatusCopy(
        label = "Awaiting payment",
        // r1498 — role-aware like Released below. The old single copy told
        // the ENGINEER "Pay ₹X into escrow to release the engineer" — the
        // hospital is the payer, and the viewer IS the engineer (found live
        // on RPR-00040's assigned-engineer view).
        subtitle = if (isHospital) {
            "Pay ${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "into escrow to release the engineer to start work."
        } else {
            "Waiting for the hospital to pay " +
                "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "into escrow. You're cleared to start once it lands."
        },
    )
    escrow.isHeld -> EscrowStatusCopy(
        label = "Funds in escrow",
        // Same role split; the 48-hour auto-release promise stays in both.
        subtitle = if (isHospital) {
            "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "is held by EquipSeva. Auto-released to engineer 48h after completion."
        } else {
            "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "is held by EquipSeva. Auto-released to you 48h after completion."
        },
    )
    escrow.isInDispute -> EscrowStatusCopy(
        label = "Dispute open",
        subtitle = "Our team is reviewing this escrow. Funds are paused until resolved.",
    )
    escrow.isReleased && payoutFailed -> EscrowStatusCopy(
        label = "Funds released — payout pending retry",
        subtitle = "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
            "left escrow but the bank transfer didn't go through. " +
            "See payout section below for next steps.",
    )
    escrow.isReleased -> EscrowStatusCopy(
        label = if (isHospital) "Released to engineer" else "Released to you",
        subtitle = if (isHospital) {
            "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "released. Settlement to engineer's bank account."
        } else {
            "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
                "released. Settlement to your bank account."
        },
    )
    escrow.isRefunded -> EscrowStatusCopy(
        label = "Refunded",
        subtitle = "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} refunded.",
    )
    else -> EscrowStatusCopy(label = "Escrow ${escrow.status}", subtitle = "")
}

/**
 * Amount + ETA hero line on the engineer's own-bid card.
 *
 * Format: "₹X" or "₹X · ETA Nh" when etaHours is non-null.
 *
 * Pin the U+00B7 middle-dot separator. Pin the "ETA Nh" form (no
 * space between N and h) — matches the bid-list card's compact form
 * so an engineer sees the same shape on both surfaces. A refactor to
 * "ETA N hours" would inflate the line width on the hero typography.
 *
 * Pin: null etaHours drops the suffix entirely (NO trailing
 * separator). A refactor that always appended " · ETA " would
 * surface a naked trailing dot when ETA is null.
 *
 * Pin: null amountRupees (repair_job_bids.amount_rupees can be null on
 * a legacy/anomalous row — see RepairBidDto's doc comment) renders "—"
 * in place of the ₹ figure rather than crashing or showing ₹0.
 */
/**
 * round3817 — is the engineer looking at this screen the one assigned to
 * the job? Two independent signals, either suffices:
 *   * `job.engineerId` (an `engineers.id`) equals the viewer's own
 *     engineers row — the authoritative link, and the ONLY one that
 *     exists for AMC visit jobs, which are pre-assigned without a bid;
 *   * the viewer's own bid on this job is Accepted — the marketplace
 *     path, and a fallback for an engineer whose engineers row could
 *     not be fetched (offline cache, transient error).
 * Pure so it can be unit-tested; the caller still ANDs it with the
 * viewer being an engineer at all.
 */
internal fun isViewerAssignedEngineer(
    job: RepairJob,
    selfEngineerRowId: String?,
    ownBid: RepairBid?,
): Boolean {
    val assignedId = job.engineerId?.takeIf { it.isNotBlank() } ?: return false
    val ownRow = selfEngineerRowId?.takeIf { it.isNotBlank() }
    return (ownRow != null && ownRow == assignedId) || ownBid?.status == RepairBidStatus.Accepted
}

internal fun ownBidAmountAndEtaLine(amountRupees: Double?, etaHours: Int?): String =
    buildString {
        append(amountRupees?.let { com.equipseva.app.core.util.formatRupees(it) } ?: "—")
        etaHours?.let { append(" · ETA ${it}h") }
    }

/**
 * ETA text on a bid card (hospital's bid list view).
 *
 * "ETA: Nh" when etaHours is known; "ETA: —" (U+2014 em-dash) when
 * null. The label always renders — hospitals scanning the bid list
 * need to see "no ETA given" as an explicit signal, not as a missing
 * field.
 *
 * Pin "ETA:" with colon-space (NOT just "ETA Nh" — colon-form
 * distinguishes the bid-list compact-row format from the own-bid
 * hero-card format which uses "ETA Nh" without colon).
 *
 * Pin U+2014 em-dash fallback — distinct from "TBD" / "Not given"
 * which would inflate the row width.
 */
internal fun bidCardEtaText(etaHours: Int?): String =
    etaHours?.let { "ETA: ${it}h" } ?: "ETA: —"

/**
 * Distance label on a bid card.
 *
 * "· X.Y km away" with U+00B7 leading separator + Locale.US-stable
 * %.1f format + "km away" suffix. Returns null when distanceKm is
 * null (engineer has no base coords OR job has no site coords) so
 * the caller can hide the chip entirely.
 *
 * Critical pin: Locale.US — hi-IN would render "3,2 km away" which
 * mis-reads. Pin "km away" suffix (not "km" alone) — disambiguates
 * the distance from the engineer's listed service radius (which is
 * also displayed in km elsewhere).
 */
internal fun bidCardDistanceLabel(distanceKm: Double?): String? =
    distanceKm?.let { "· ${"%.1f".format(java.util.Locale.US, it)} km away" }

/** Min days a job sits unmatched before the hospital sees the nudge banner. */
private const val UNMATCHED_JOB_BANNER_MIN_DAYS = 7L

/**
 * Whether the "No bids yet · raise your budget" UnmatchedJobBanner shows on
 * the job detail. Only for a hospital viewing a genuinely OPEN marketplace
 * job — Requested, UNASSIGNED (engineerId == null), with no bids, sitting for
 * at least a week.
 *
 * The `engineerId == null` clause is load-bearing (r1482): an AMC maintenance
 * visit is created in Requested status but pre-assigned to the contract's
 * engineer, so without it the banner nudges the hospital to attract bids on a
 * job that already has an engineer and never goes out for bidding. Pure +
 * tested so a future edit can't silently drop that clause.
 */
internal fun shouldShowUnmatchedJobBanner(
    isHospital: Boolean,
    status: RepairJobStatus,
    engineerId: String?,
    hasBids: Boolean,
    daysOld: Long,
): Boolean =
    isHospital &&
        status == RepairJobStatus.Requested &&
        engineerId == null &&
        !hasBids &&
        daysOld >= UNMATCHED_JOB_BANNER_MIN_DAYS

/**
 * Whether the hospital-facing "Bids" section (the bid list, or the "No bids
 * yet" card) shows. Same OPEN-marketplace gate as the banner minus the age /
 * bid-count checks: a hospital viewing a Requested, UNASSIGNED job. AMC visits
 * (engineerId != null) are excluded (r1483) so the "engineers usually bid in
 * 5–30 min" card can't contradict the Assigned-engineer section above it.
 */
internal fun shouldShowBidsSection(
    isHospital: Boolean,
    status: RepairJobStatus,
    engineerId: String?,
): Boolean =
    isHospital &&
        status == RepairJobStatus.Requested &&
        engineerId == null

/**
 * Placeholder copy on the RepairJobDetail location card when we
 * can't render a map.
 *
 * 4-state decision tree:
 *   1. canShowAddress (the address IS visible to this viewer) → "No
 *      map pin saved for this job" (the address text exists but lat/lng
 *      doesn't — this is a legacy backfill case)
 *   2. !hasAddressOnFile → "No address on file yet" (no data anywhere)
 *   3. isEngineer (address exists but engineer can't see it) →
 *      "Address hidden until the hospital accepts your bid" — pin
 *      "hospital accepts your bid" framing because engineers DON'T
 *      "accept" jobs; they bid. Hospitals accept.
 *   4. else (hospital viewing a job where address is hidden) →
 *      generic "Address hidden until a bid is accepted"
 *
 * Critical regression target: the engineer-facing copy mentions "your
 * bid" because old phrasing said "accept the job" — engineers got
 * confused looking for an accept button that didn't exist.
 */
internal fun locationCardPlaceholderCopy(
    canShowAddress: Boolean,
    hasAddressOnFile: Boolean,
    isEngineer: Boolean,
): String = when {
    canShowAddress -> "No map pin saved for this job"
    !hasAddressOnFile -> "No address on file yet"
    isEngineer -> "Address hidden until the hospital accepts your bid"
    else -> "Address hidden until a bid is accepted"
}

/**
 * Submit gate on the engineer dispute-response sheet.
 *
 * Requires:
 *   1. response (trimmed) is at least 10 characters
 *   2. NOT currently submitting (prevents double-tap)
 *
 * Pin the 10-char minimum — load-bearing because admin needs
 * substantive context to decide release vs refund. A "yes" or "ok"
 * response would be useless evidence. A refactor that relaxed the
 * floor to >= 1 would let trivial responses through.
 *
 * Pin .trim().length (not just .length) — pure-whitespace responses
 * shouldn't enable submit even if they hit the char count.
 */
internal fun canSubmitEngineerResponse(response: String, submitting: Boolean): Boolean =
    response.trim().length >= 10 && !submitting

/**
 * Amount-field validation gate on the bid composer sheet.
 *
 * True when the amount parses to a positive (> 0.0) Double.
 *
 * Pin strict > 0.0 (not >=) — a 0-rupee bid would be a free-job offer
 * which the server-side CHECK rejects with `amount_must_be_positive`.
 * Pin null-on-non-numeric — toDoubleOrNull returns null for input
 * the user typed but hasn't completed yet.
 *
 * Note: the buildRepairBidInsert helper also enforces this server-
 * side; this client gate is just for the UI affordance.
 */
internal fun bidComposerAmountValid(amount: String): Boolean {
    val parsed = amount.toDoubleOrNull()
    return parsed != null && parsed > 0.0
}

/**
 * ETA-field validation gate on the bid composer sheet.
 *
 * True when EITHER:
 *   - the ETA field is blank/empty (ETA is optional)
 *   - OR the ETA parses to a positive (> 0) Int
 *
 * Pin the blank-as-valid branch — ETA is optional per the
 * RepairBidInsert wire schema (etaHours: Int? = null). A refactor
 * that required a value would silently break bids that don't
 * specify an ETA.
 *
 * Pin > 0 strict — a 0-hour ETA would be meaningless. The
 * buildRepairBidInsert helper also enforces this server-side.
 */
internal fun bidComposerEtaValid(eta: String): Boolean {
    val trimmed = eta.trim()
    if (trimmed.isEmpty()) return true
    val parsed = trimmed.toIntOrNull()
    return parsed != null && parsed > 0
}

/* ------------------ round 431 — engineer payout status card ----------------- */

/**
 * Hospital reads "Paid to engineer via UPI" — emphasises what THEY
 * paid for. Engineer reads "Paid by EquipSeva" — emphasises what they
 * received. Both anti-disintermediation framings.
 */
internal fun engineerPayoutTitle(
    p: com.equipseva.app.core.data.payouts.JobPayoutStatus,
    isHospital: Boolean,
): String = when (p.status) {
    com.equipseva.app.core.data.payouts.PayoutStatus.Queued ->
        if (isHospital) "Engineer payout queued" else "Your payout is queued"
    com.equipseva.app.core.data.payouts.PayoutStatus.Processing ->
        if (isHospital) "Engineer payout in flight" else "Your payout is on its way"
    com.equipseva.app.core.data.payouts.PayoutStatus.Processed ->
        if (isHospital) "Paid to engineer" else "Paid to your account"
    com.equipseva.app.core.data.payouts.PayoutStatus.Failed ->
        if (isHospital) "Engineer payout failed" else "Your payout failed"
    com.equipseva.app.core.data.payouts.PayoutStatus.Cancelled ->
        "Payout cancelled"
}

internal fun engineerPayoutSubtitle(
    p: com.equipseva.app.core.data.payouts.JobPayoutStatus,
    isHospital: Boolean,
): String? = when (p.status) {
    com.equipseva.app.core.data.payouts.PayoutStatus.Queued ->
        if (isHospital) "Will be transferred to ${p.engineerName ?: "the engineer"} shortly."
        else "We'll transfer to ${p.destinationLabel ?: "your account"} on the next worker tick."
    com.equipseva.app.core.data.payouts.PayoutStatus.Processing ->
        if (isHospital) "Sent to ${p.destinationLabel ?: "engineer's account"} — awaiting bank confirmation."
        else "Sent to ${p.destinationLabel ?: "your account"} — awaiting confirmation."
    com.equipseva.app.core.data.payouts.PayoutStatus.Processed ->
        if (isHospital) "${p.engineerName ?: "Engineer"} received via ${p.mode ?: "UPI"} to ${p.destinationLabel ?: "their account"}."
        else "Received via ${p.mode ?: "UPI"} at ${p.destinationLabel ?: "your account"}."
    com.equipseva.app.core.data.payouts.PayoutStatus.Failed ->
        if (isHospital) "We'll retry automatically. No action needed from you."
        else "Re-check your payout method — we'll retry on the next worker tick."
    com.equipseva.app.core.data.payouts.PayoutStatus.Cancelled ->
        if (isHospital) "Admin cancelled this payout." else "Admin cancelled. Reach out if unexpected."
}
