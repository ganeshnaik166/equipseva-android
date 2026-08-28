package com.equipseva.app.features.repair

import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.Avatar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.HelpSupportSheet
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.components.UrgencyPill
import com.equipseva.app.designsystem.components.VerifiedBadge
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaDanger700
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import kotlinx.coroutines.launch

private val WarnGold = Color(0xFFF5A623)

// Upper bound on the engineer's bid note. 500 chars keeps the payload
// small and the hospital-side card readable without an "expand" gesture.
private const val NOTE_MAX_LEN = 500

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
    viewModel: RepairJobDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var withdrawConfirmOpen by rememberSaveable { mutableStateOf(false) }
    var checkinSheetOpen by rememberSaveable { mutableStateOf(false) }
    var cancelSheetOpen by rememberSaveable { mutableStateOf(false) }
    var rateSheetOpen by rememberSaveable { mutableStateOf(false) }
    // FIX #10 — Help & Support escalation sheet, opened from the '?'
    // icon in the top bar. Passes jobNumber so the report-form mailto
    // subject is pre-tagged with the public job ref.
    var helpSheetOpen by rememberSaveable { mutableStateOf(false) }

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

    Scaffold(
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
                                            viewModel.onOpenReport()
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
                    viewerRole = state.viewerRole,
                    updatingStatus = state.updatingStatus,
                    queuedStatusCount = state.queuedStatusCount,
                    pendingCostRevision = state.pendingCostRevision,
                    onPlaceBid = viewModel::openBidComposer,
                    onCheckIn = { checkinSheetOpen = true },
                    onMarkDone = viewModel::openProofSheet,
                    onRate = { rateSheetOpen = true },
                    onCancel = { cancelSheetOpen = true },
                    onReviseQuote = viewModel::openReviseQuoteSheet,
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
                            onTap = viewModel::openRevisionDecisionSheet,
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
                    message = state.errorMessage!!,
                    onRetry = viewModel::retry,
                )
                state.job != null -> JobBody(
                    job = state.job!!,
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
                    onMessageEngineer = viewModel::openChatWithEngineer,
                    onMessageHospital = viewModel::openChatWithHospital,
                    onAcceptBid = viewModel::acceptBid,
                    onWithdraw = { withdrawConfirmOpen = true },
                    onDownloadReport = viewModel::generateServiceReport,
                    onDownloadInvoice = viewModel::generateInvoice,
                    onPayEscrow = viewModel::openEscrowPaymentSheet,
                    onConfirmEscrowRelease = viewModel::confirmEscrowRelease,
                    onOpenEscrowDispute = viewModel::openEscrowDisputeSheet,
                    onOpenEngineerResponseSheet = viewModel::openEngineerResponseSheet,
                    onOpenPayoutMethod = onOpenPayoutMethod,
                )
            }
        }
    }

    if (state.bidComposerOpen && state.job != null) {
        BidComposerSheet(
            existingBid = state.ownBid?.takeIf { it.status == RepairBidStatus.Pending },
            placingBid = state.placingBid,
            onDismiss = viewModel::closeBidComposer,
            onSubmit = viewModel::submitBid,
        )
    }

    if (state.proofSheetOpen && state.job != null) {
        CompletionProofSheet(
            submitting = state.submittingProof,
            onDismiss = viewModel::closeProofSheet,
            onSubmit = viewModel::submitCompletionProof,
        )
    }

    if (checkinSheetOpen) {
        CheckinSheet(
            updating = state.updatingStatus,
            onDismiss = { if (!state.updatingStatus) checkinSheetOpen = false },
            onConfirm = { photos ->
                checkinSheetOpen = false
                viewModel.submitCheckinWithProof(photos)
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
                viewModel.cancelJob(reason = reason)
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
                    viewModel.submitRating(stars, note)
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
                onDismiss = viewModel::closeReviseQuoteSheet,
                onSubmit = { amount, reason -> viewModel.proposeCostRevision(amount, reason) },
            )
        }
    }

    if (state.revisionDecisionSheetOpen) {
        val rev = state.pendingCostRevision
        if (rev != null) {
            com.equipseva.app.features.repair.components.CostRevisionDecisionSheet(
                revision = rev,
                deciding = state.decidingRevision,
                onDismiss = viewModel::closeRevisionDecisionSheet,
                onDecide = { approve -> viewModel.decideCostRevision(approve) },
            )
        }
    }

    if (state.reportingTargetId != null) {
        ReportContentSheet(
            titleLabel = "Report this repair job",
            submitting = state.submittingReport,
            onDismiss = viewModel::onDismissReport,
            onSubmit = viewModel::onSubmitReport,
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
        val bid = state.selectedBidForSummary!!
        val engineerName = state.engineerNames[bid.engineerUserId] ?: "the engineer"
        OrderSummarySheet(
            job = state.job!!,
            bid = bid,
            engineerName = engineerName,
            onClose = viewModel::closeOrderSummarySheet,
            onProceedToPayment = viewModel::proceedToPaymentFromSummary,
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
            repairJobId = state.job!!.id,
            amountRupees = escrow.amountRupees,
            engineerName = engineerName,
            onClose = viewModel::closeEscrowPaymentSheet,
            onShowMessage = onShowMessage,
            onCompleted = viewModel::refreshEscrow,
        )
    }

    // PR-D5: hospital opens a dispute (within 48h post-completion).
    if (state.escrowDisputeSheetOpen) {
        EscrowDisputeSheet(
            submitting = state.openingEscrowDispute,
            onDismiss = viewModel::closeEscrowDisputeSheet,
            onSubmit = viewModel::openEscrowDispute,
        )
    }

    // PR-D29: engineer responds to a hospital's dispute.
    if (state.engineerResponseSheetOpen) {
        EngineerResponseSheet(
            submitting = state.submittingEngineerResponse,
            onDismiss = viewModel::closeEngineerResponseSheet,
            onSubmit = viewModel::submitEngineerResponse,
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
                        viewModel.withdrawBid()
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

@Composable
private fun InvoiceDownloadCard(
    loading: Boolean,
    onDownload: () -> Unit,
) {
    androidx.compose.foundation.layout.Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_invoice_download_body),
            style = MaterialTheme.typography.bodySmall,
        )
        EsBtn(
            text = if (loading) "Generating invoice…" else "Download GST invoice",
            onClick = onDownload,
            kind = EsBtnKind.Ghost,
            disabled = loading,
        )
    }
}

@Composable
private fun EscrowDisputeSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var reason by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onDismiss, title = "Open a dispute") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                stringResource(R.string.repair_dispute_open_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            OutlinedTextField(
                value = reason,
                onValueChange = { if (it.length <= 500) reason = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.repair_dispute_open_placeholder)) },
                minLines = 3,
                maxLines = 6,
            )
            val canOpen = canSubmitEngineerResponse(reason, submitting)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (canOpen) SevaDanger500 else SevaInk300)
                    .clickable(enabled = canOpen) {
                        onSubmit(reason.trim())
                    }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (submitting) stringResource(R.string.repair_dispute_opening) else stringResource(R.string.repair_dispute_open_action),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun EngineerResponseSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var response by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onDismiss, title = "Respond to dispute") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                stringResource(R.string.repair_dispute_respond_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            OutlinedTextField(
                value = response,
                onValueChange = { if (it.length <= 500) response = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.repair_dispute_respond_placeholder)) },
                minLines = 3,
                maxLines = 6,
            )
            val canSubmit = canSubmitEngineerResponse(response, submitting)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (canSubmit) SevaGreen700 else SevaInk300)
                    .clickable(enabled = canSubmit) {
                        onSubmit(response.trim())
                    }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (submitting) stringResource(R.string.repair_dispute_submitting) else stringResource(R.string.repair_dispute_submit_response),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

/**
 * Defensive placeholder for a job that's logically past the
 * accept-bid step but has NO escrow row to render. PR #1033 restored
 * the per-job escrow INSERT in accept_repair_bid; this card protects
 * against any future regression OR partial-failure race that leaves
 * the row absent. Without it the hospital sees a job stuck at
 * "Assigned" with no Pay button and no signal what to do.
 */
@Composable
private fun EscrowMissingPlaceholderCard() {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SevaWarning50)
            .border(width = 1.dp, color = SevaWarning500, shape = shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            stringResource(R.string.repair_escrow_missing_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            stringResource(R.string.repair_escrow_missing_body),
            fontSize = 12.sp,
            color = SevaInk700,
        )
    }
}

@Composable
private fun EscrowStatusCard(
    escrow: com.equipseva.app.core.data.escrow.RepairJobEscrowRepository.EscrowRow,
    isHospital: Boolean,
    isJobCompleted: Boolean,
    confirmingRelease: Boolean,
    // Round 437 fix #5 — true when the downstream engineer payout
    // has flipped to Failed / Cancelled despite escrow.isReleased.
    // Used to swap the misleading "Released to engineer" copy for
    // a more accurate "Funds released — payout to engineer pending
    // retry" reading. Defaults false so existing call sites
    // (anywhere we don't yet know payout status) behave as before.
    payoutFailed: Boolean = false,
    onPay: () -> Unit,
    onConfirmRelease: () -> Unit,
    onOpenDispute: () -> Unit,
    onOpenEngineerResponse: () -> Unit,
) {
    val copy = escrowStatusCardCopy(escrow, isHospital, payoutFailed)
    val label = copy.label
    val sub = copy.subtitle
    val accent = when {
        escrow.isPending -> WarnGold
        escrow.isHeld -> SevaGreen700
        escrow.isInDispute -> SevaDanger500
        // (#5) When the downstream payout failed, downgrade the
        // escrow card's green to a warning tone so the visual
        // doesn't contradict the copy.
        escrow.isReleased && payoutFailed -> SevaWarning500
        escrow.isReleased -> SevaGreen700
        escrow.isRefunded -> SevaInk700
        else -> SevaInk500
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(text = label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = accent)
        if (sub.isNotBlank()) {
            Text(text = sub, fontSize = 12.sp, color = SevaInk500)
        }
        // Show the dispute reason text + the engineer's response (when set)
        // on both sides — admins, hospitals, and engineers all benefit from
        // seeing the back-and-forth before the resolution lands.
        if (escrow.isInDispute) {
            if (!escrow.disputeReason.isNullOrBlank()) {
                Text(
                    stringResource(R.string.repair_escrow_dispute_hospital_prefix, escrow.disputeReason),
                    color = SevaInk700,
                    fontSize = 13.sp,
                )
            }
            if (!escrow.engineerResponse.isNullOrBlank()) {
                Text(
                    stringResource(R.string.repair_escrow_dispute_engineer_prefix, escrow.engineerResponse),
                    color = SevaInk700,
                    fontSize = 13.sp,
                )
            } else if (!isHospital) {
                // Engineer hasn't responded yet — surface the CTA. One-shot;
                // server rejects a second submission so the UI hides this
                // once `engineer_response` is set.
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White)
                        .border(1.dp, SevaDanger500, RoundedCornerShape(10.dp))
                        .clickable(onClick = onOpenEngineerResponse)
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(R.string.repair_escrow_respond_to_dispute),
                        color = SevaDanger500,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
            }
        }
        if (isHospital && escrow.isPending) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SevaGreen700)
                    .clickable(onClick = onPay)
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.repair_escrow_pay_amount, formatRupees(escrow.amountRupees)),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
        }
        if (isHospital && escrow.isHeld && isJobCompleted) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(SevaGreen700)
                        .clickable(enabled = !confirmingRelease, onClick = onConfirmRelease)
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (confirmingRelease) stringResource(R.string.repair_escrow_releasing) else stringResource(R.string.repair_escrow_confirm_release),
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
                if (escrow.isInDisputeWindow) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White)
                            .border(1.dp, SevaDanger500, RoundedCornerShape(10.dp))
                            .clickable(onClick = onOpenDispute)
                            .padding(vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            stringResource(R.string.repair_dispute_open_action),
                            color = SevaDanger500,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ServiceReportCard(
    loading: Boolean,
    onDownload: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_service_report_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = stringResource(R.string.repair_service_report_body),
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGreen700)
                .clickable(enabled = !loading, onClick = onDownload)
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (loading) stringResource(R.string.repair_service_report_generating) else stringResource(R.string.repair_service_report_download),
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
            )
        }
    }
}

@Composable
private fun TerminalStatusBanner(title: String, subtitle: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SevaDanger50)
            .border(1.dp, SevaDanger500, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Block,
            contentDescription = null,
            tint = SevaDanger500,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaDanger700,
            )
            Text(
                text = subtitle,
                fontSize = 11.sp,
                color = SevaInk500,
            )
        }
    }
}

@Composable
private fun WarrantyBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SevaGreen50)
            .border(1.dp, SevaGreen700, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Shield,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.repair_warranty_title),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaGreen900,
            )
            Text(
                text = stringResource(R.string.repair_warranty_body),
                fontSize = 11.sp,
                color = SevaInk500,
            )
        }
    }
}

// --- Hospital banner --------------------------------------------------------
@Composable
private fun HospitalBanner(siteName: String, siteCity: String?, urgency: com.equipseva.app.core.data.repair.RepairJobUrgency) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Apartment,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = siteName,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                )
                VerifiedBadge(small = true)
            }
            if (!siteCity.isNullOrBlank()) {
                Text(
                    text = siteCity,
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
            }
        }
        UrgencyPill(urgency = urgency)
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

@Composable
private fun StatusStepperRow(currentStatus: RepairJobStatus) {
    val currentIdx = statusStepIndex(currentStatus)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            StepStatuses.forEachIndexed { i, _ ->
                val done = currentIdx >= 0 && i < currentIdx
                val active = i == currentIdx
                Column(
                    modifier = Modifier.width(56.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    StepDot(done = done, active = active, number = i + 1)
                    Text(
                        text = StepLabels[i],
                        fontSize = 9.sp,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (active) SevaInk900 else SevaInk400,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (i < StepStatuses.lastIndex) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .padding(bottom = 18.dp)
                            .height(2.dp)
                            .background(if (i < currentIdx) SevaGreen700 else BorderDefault),
                    )
                }
            }
        }
    }
}

@Composable
private fun StepDot(done: Boolean, active: Boolean, number: Int) {
    val bg = when {
        done -> SevaGreen700
        active -> Color.White
        else -> Paper2
    }
    val borderColor = when {
        done -> SevaGreen700
        active -> SevaGreen700
        else -> BorderDefault
    }
    val borderW = if (active) 2.dp else 1.dp
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(CircleShape)
            .background(bg)
            .border(borderW, borderColor, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            done -> Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(12.dp),
            )
            else -> Text(
                text = number.toString(),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = if (active) SevaGreen700 else SevaInk400,
            )
        }
    }
}

// --- Equipment card ---------------------------------------------------------
@Composable
private fun EquipmentCard(job: RepairJob) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        EqRow("Brand", textOrDash(job.equipmentBrand))
        Spacer(Modifier.height(8.dp))
        EqRow("Model", textOrDash(job.equipmentModel))
        Spacer(Modifier.height(8.dp))
        EqRow("Category", job.equipmentCategory.displayName)
        Spacer(Modifier.height(8.dp))
        EqRow("Schedule", equipmentScheduleLine(job.scheduledDate, job.scheduledTimeSlot))
    }
}

@Composable
private fun EqRow(label: String, value: String) {
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = label,
            fontSize = 13.sp,
            color = SevaInk500,
            modifier = Modifier.width(90.dp),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = value,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
            modifier = Modifier.weight(1f),
        )
    }
}

// --- Issue card -------------------------------------------------------------
@Composable
private fun IssueCard(job: RepairJob, issuePhotoUrls: List<String>) {
    val urls = issuePhotoUrls.take(4)
    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
        ) {
            Text(
                text = job.issueDescription,
                fontSize = 13.sp,
                color = SevaInk700,
                lineHeight = 19.sp,
            )
        }
        if (urls.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp)
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                urls.forEach { url ->
                    coil3.compose.AsyncImage(
                        model = url,
                        contentDescription = null,
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Paper2),
                    )
                }
            }
        }
    }
}

// --- Assigned engineer card ------------------------------------------------
@Composable
private fun AssignedEngineerCard(
    name: String,
    openingChat: Boolean,
    onMessage: () -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Avatar(initials = initialsOf(name), size = 44.dp)
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = name,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaInk900,
                    )
                    VerifiedBadge(small = true)
                }
            }
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = SevaInk400,
                modifier = Modifier.size(18.dp),
            )
        }
        Row(
            modifier = Modifier
                .padding(top = 8.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Dropped the always-disabled "Call" button — its onClick was
            // mis-wired to onMessage anyway, so if it ever flipped enabled
            // it would have opened chat instead of dialing. Masked-call
            // path lives on the engineer-profile MaskedContactPanel; the
            // assigned-engineer card here is just a chat shortcut.
            EsBtn(
                text = if (openingChat) "Opening…" else "Message",
                onClick = onMessage,
                kind = EsBtnKind.Secondary,
                full = true,
                disabled = openingChat,
                leading = {
                    Icon(
                        imageVector = Icons.Outlined.ChatBubbleOutline,
                        contentDescription = null,
                        tint = SevaInk700,
                        modifier = Modifier.size(16.dp),
                    )
                },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// --- Bids list (hospital view) ---------------------------------------------
@Composable
private fun BidsList(
    bids: List<RepairBid>,
    engineerNames: Map<String, String>,
    acceptingBidId: String?,
    openingChat: Boolean,
    onAccept: (String) -> Unit,
    onMessage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        bids.forEach { bid ->
            BidCard(
                bid = bid,
                engineerName = engineerNames[bid.engineerUserId] ?: "Engineer",
                accepting = acceptingBidId == bid.id,
                anyAccepting = acceptingBidId != null,
                openingChat = openingChat,
                onAccept = onAccept,
                onMessage = onMessage,
            )
        }
    }
}

@Composable
private fun NoBidsYetCard() {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_nobids_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = stringResource(R.string.repair_nobids_body),
            fontSize = 12.sp,
            color = SevaInk500,
        )
    }
}

@Composable
private fun BidCard(
    bid: RepairBid,
    engineerName: String,
    accepting: Boolean,
    anyAccepting: Boolean,
    openingChat: Boolean,
    onAccept: (String) -> Unit,
    onMessage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Avatar(initials = initialsOf(engineerName), size = 36.dp)
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = engineerName,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaInk900,
                    )
                    VerifiedBadge(small = true)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    // Round 3760 — repair_job_bids.amount_rupees can be
                    // null on a legacy/anomalous row; show "—" rather
                    // than crash or a misleading ₹0.
                    text = bid.amountRupees?.let { formatRupees(it) } ?: "—",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaGreen700,
                )
                bid.createdAtInstant?.let { placed ->
                    Text(
                        text = stringResource(R.string.repair_bidcard_placed_ago, relativeLabel(placed)),
                        fontSize = 10.sp,
                        color = SevaInk400,
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(BorderDefault),
        )
        Spacer(Modifier.height(8.dp))
        // PR-B: ETA + distance chip line. Distance comes from the new
        // list_repair_job_bids_with_distance RPC; null when the engineer
        // has no base coords or the job has no site coords — chip hides.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = bidCardEtaText(bid.etaHours),
                fontSize = 12.sp,
                color = SevaInk600,
                lineHeight = 17.sp,
            )
            val distanceLabel = bidCardDistanceLabel(bid.distanceKm)
            if (distanceLabel != null) {
                Text(
                    text = distanceLabel,
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
            }
        }
        if (!bid.note.isNullOrBlank()) {
            Text(
                text = bid.note,
                fontSize = 12.sp,
                color = SevaInk600,
                lineHeight = 17.sp,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Row(
            modifier = Modifier
                .padding(top = 10.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            EsBtn(
                text = "Message",
                onClick = onMessage,
                kind = EsBtnKind.Secondary,
                disabled = openingChat,
            )
            EsBtn(
                text = if (accepting) "Accepting…" else "Accept this bid",
                onClick = { if (!anyAccepting) onAccept(bid.id) },
                kind = EsBtnKind.Primary,
                full = true,
                disabled = anyAccepting,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// --- Engineer's own bid card -----------------------------------------------
@Composable
private fun YourBidCard(ownBid: RepairBid, onWithdraw: () -> Unit) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(14.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_yourbid_label),
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Text(
            text = ownBidAmountAndEtaLine(ownBid.amountRupees, ownBid.etaHours),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = SevaGreen900,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = stringResource(R.string.repair_yourbid_status_prefix, ownBid.status.displayName),
            fontSize = 12.sp,
            color = SevaInk700,
            modifier = Modifier.padding(top = 4.dp),
        )
        if (!ownBid.note.isNullOrBlank()) {
            Text(
                text = ownBid.note,
                fontSize = 12.sp,
                color = SevaInk700,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        if (ownBid.status == RepairBidStatus.Pending) {
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = "Withdraw bid",
                onClick = onWithdraw,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Sm,
            )
        }
    }
}

// --- Location card ----------------------------------------------------------
@Composable
private fun LocationCard(
    job: RepairJob,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
) {
    val context = LocalContext.current
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val hasAddressOnFile = !job.siteLocation.isNullOrBlank()
    val canShowAddress = hasAddressOnFile &&
        (isHospital || (isEngineer && job.isAssignedToEngineer))
    val placeholderCopy = locationCardPlaceholderCopy(
        canShowAddress = canShowAddress,
        hasAddressOnFile = hasAddressOnFile,
        isEngineer = isEngineer,
    )

    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        // Render a real map when we have coords; fall back to the placeholder
        // tile when the job row never captured a lat/lng (legacy rows from
        // before PR #219 wired the map picker into RequestService Step 4).
        if (job.siteLatitude != null && job.siteLongitude != null) {
            val target = com.google.android.gms.maps.model.LatLng(job.siteLatitude!!, job.siteLongitude!!)
            val cameraState = com.google.maps.android.compose.rememberCameraPositionState {
                position = com.google.android.gms.maps.model.CameraPosition.fromLatLngZoom(target, 15f)
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp)),
            ) {
                com.google.maps.android.compose.GoogleMap(
                    cameraPositionState = cameraState,
                    properties = com.google.maps.android.compose.MapProperties(isMyLocationEnabled = false),
                    uiSettings = com.google.maps.android.compose.MapUiSettings(
                        zoomControlsEnabled = false,
                        mapToolbarEnabled = false,
                        scrollGesturesEnabled = true,
                        zoomGesturesEnabled = true,
                        tiltGesturesEnabled = false,
                        rotationGesturesEnabled = false,
                    ),
                ) {
                    val markerState = com.google.maps.android.compose.rememberMarkerState(
                        key = "site-${job.siteLatitude}-${job.siteLongitude}",
                        position = target,
                    )
                    com.google.maps.android.compose.Marker(
                        state = markerState,
                        title = "Service site",
                    )
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Paper3),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.LocationOn,
                        contentDescription = null,
                        tint = SevaGreen700,
                        modifier = Modifier.size(28.dp),
                    )
                    Text(
                        text = placeholderCopy,
                        fontSize = 11.sp,
                        color = SevaInk500,
                    )
                    if (canShowAddress) {
                        Text(
                            text = job.siteLocation!!.lineSequence().firstOrNull().orEmpty(),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = SevaInk900,
                        )
                    }
                }
            }
        }
        if (canShowAddress) {
            Text(
                text = job.siteLocation!!,
                fontSize = 13.sp,
                color = SevaInk900,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 8.dp),
            )
            if (isEngineer) {
                Spacer(Modifier.height(8.dp))
                EsBtn(
                    text = "Navigate to site",
                    onClick = {
                        val encoded = Uri.encode(job.siteLocation)
                        val uri = if (job.siteLatitude != null && job.siteLongitude != null) {
                            val label = Uri.encode("Service site")
                            "geo:${job.siteLatitude},${job.siteLongitude}?q=${job.siteLatitude},${job.siteLongitude}($label)".toUri()
                        } else {
                            "geo:0,0?q=$encoded".toUri()
                        }
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uri)
                        try {
                            context.startActivity(intent)
                        } catch (_: android.content.ActivityNotFoundException) {
                            val fallbackUrl = if (job.siteLatitude != null && job.siteLongitude != null) {
                                "https://www.google.com/maps/dir/?api=1&destination=${job.siteLatitude},${job.siteLongitude}"
                            } else {
                                "https://www.google.com/maps/dir/?api=1&destination=$encoded"
                            }
                            val fallback = android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                fallbackUrl.toUri(),
                            )
                            try {
                                context.startActivity(fallback)
                            } catch (_: android.content.ActivityNotFoundException) {
                                // No maps app AND no browser — extremely rare,
                                // but silently dropping the tap was confusing.
                                android.widget.Toast.makeText(
                                    context,
                                    "No app available to open this location",
                                    android.widget.Toast.LENGTH_SHORT,
                                ).show()
                            }
                        }
                    },
                    kind = EsBtnKind.Secondary,
                    leading = {
                        Icon(
                            imageVector = Icons.Outlined.LocationOn,
                            contentDescription = null,
                            tint = SevaGreen700,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            }
        } else {
            Text(
                text = if (isEngineer)
                    stringResource(R.string.repair_location_address_hidden_engineer)
                else
                    stringResource(R.string.repair_location_address_hidden_hospital),
                fontSize = 12.sp,
                color = SevaInk500,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

// --- Completion proof card --------------------------------------------------
@Composable
private fun CompletionProofCard(urls: List<String>) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(urls, key = { it }) { url ->
                AsyncImage(
                    model = url,
                    contentDescription = "Completion photo",
                    modifier = Modifier
                        .size(96.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Paper2),
                    contentScale = ContentScale.Crop,
                )
            }
        }
        Text(
            text = stringResource(R.string.repair_completion_proof_body),
            fontSize = 12.sp,
            color = SevaInk500,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

// --- Sticky bottom bar ------------------------------------------------------
@Composable
private fun StickyBottomBar(
    job: RepairJob,
    ownBid: RepairBid?,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    updatingStatus: Boolean,
    queuedStatusCount: Int,
    pendingCostRevision: com.equipseva.app.core.data.repair.CostRevision?,
    onPlaceBid: () -> Unit,
    onCheckIn: () -> Unit,
    onMarkDone: () -> Unit,
    onRate: () -> Unit,
    onCancel: () -> Unit,
    onReviseQuote: () -> Unit,
    // v0.3.5 fix #9 — Book-again CTA, hospital-only, surfaces on
    // Completed jobs once the hospital has rated the engineer (so
    // it doesn't compete with the Rate prompt). engineerId is
    // job.engineerId (engineers.id, what the directory uses).
    onBookAgain: (engineerId: String) -> Unit = {},
) {
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val rated = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating != null
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating != null
        RepairJobDetailViewModel.ViewerRole.Other -> true
    }
    // Hospital can cancel their own job (Requested or Assigned).
    // Engineer can cancel only if they're the assigned engineer (Assigned status).
    // Random engineer browsing a Requested job: no Cancel — they haven't
    // committed to anything yet; the negative action would be a no-op.
    val isAssignedEngineer = isEngineer && job.engineerId != null && ownBid?.status == RepairBidStatus.Accepted
    val canCancel = when {
        isHospital -> job.status in setOf(RepairJobStatus.Requested, RepairJobStatus.Assigned)
        isAssignedEngineer -> job.status == RepairJobStatus.Assigned
        else -> false
    }

    // Resolve which primary CTA to show. Null = no primary (e.g. Other role,
    // or terminal states without a CTA + without cancel).
    val primaryKind: PrimaryCta? = when {
        isEngineer && job.status == RepairJobStatus.Requested ->
            PrimaryCta.PlaceBid(editing = ownBid?.status == RepairBidStatus.Pending)
        isEngineer && job.status == RepairJobStatus.Assigned -> PrimaryCta.CheckIn
        isEngineer && (job.status == RepairJobStatus.EnRoute || job.status == RepairJobStatus.InProgress) ->
            PrimaryCta.MarkDone
        isHospital && job.status == RepairJobStatus.Completed && !rated -> PrimaryCta.Rate
        isHospital && job.status == RepairJobStatus.Completed && rated -> PrimaryCta.RatedDone
        // Engineer side mirrors hospital: once the job lands in Completed,
        // give the engineer the same Rate / RatedDone CTA against
        // engineer_rating (server enforces side-identity).
        isEngineer && job.status == RepairJobStatus.Completed && !rated -> PrimaryCta.Rate
        isEngineer && job.status == RepairJobStatus.Completed && rated -> PrimaryCta.RatedDone
        else -> null
    }

    // v0.3.5 fix #9 — hospital-side "Book this engineer again" CTA.
    // Surfaces only on Completed jobs where:
    //   * the viewer is the hospital (engineer wouldn't book themselves),
    //   * a specific engineer was assigned (engineerId non-null — repeat
    //     bookings need a target),
    //   * the hospital has already rated the engineer — gating on rated
    //     keeps the bottom bar a single primary CTA (Rate) until that's
    //     done, then swaps the slot to the higher-LTV re-book action.
    val showBookAgain = isHospital &&
        job.status == RepairJobStatus.Completed &&
        rated &&
        job.engineerId != null

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(1.dp, BorderDefault, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        when (primaryKind) {
            is PrimaryCta.PlaceBid -> EsBtn(
                text = if (primaryKind.editing) "Edit bid" else "Place bid",
                onClick = onPlaceBid,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.CheckIn -> EsBtn(
                text = when {
                    updatingStatus -> "Working…"
                    queuedStatusCount > 0 -> "Queued — back online"
                    else -> "Check in on-site"
                },
                onClick = onCheckIn,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                // Also disable while a status flip is queued offline. The
                // local job.status was optimistically updated when the
                // queue happened, so the gate at transitionStatus would
                // bounce a second tap, but the button itself shouldn't
                // tempt the user. The label change tells them why.
                disabled = updatingStatus || queuedStatusCount > 0,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.MarkDone -> EsBtn(
                text = when {
                    updatingStatus -> "Marking…"
                    queuedStatusCount > 0 -> "Queued — back online"
                    else -> "Mark done"
                },
                onClick = onMarkDone,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                // Mirror CheckIn. Double-tap mid-flight used to fire two
                // 'Completed' RPCs — server-side trigger rejected the
                // second one but the user saw a spurious error toast.
                // Also gate on queuedStatusCount: an offline tap
                // optimistically flips local status, but the row is still
                // pending drain; a second tap before drain would queue
                // another row that the server-side state-machine guard
                // would later reject.
                disabled = updatingStatus || queuedStatusCount > 0,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.Rate -> EsBtn(
                // Hospital rates the engineer; engineer rates the hospital.
                // Same CTA + same flow, different counterpart label so the
                // copy isn't ambiguous on the engineer side.
                text = if (isHospital) "Rate engineer" else "Rate hospital",
                onClick = onRate,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.RatedDone -> {
                // v0.3.5 fix #9 — once the hospital has rated the engineer
                // on a completed job, the bottom slot becomes a prominent
                // "Book this engineer again" primary CTA. Repeat bookings
                // are the highest-LTV path on this surface; the old
                // disabled "Rated · Thanks!" pill wasted prime real
                // estate. Engineers still see the disabled pill (no
                // re-book affordance for the engineer side).
                if (showBookAgain) {
                    EsBtn(
                        text = "★ Book this engineer again",
                        onClick = { onBookAgain(job.engineerId!!) },
                        kind = EsBtnKind.Primary,
                        full = true,
                        size = EsBtnSize.Lg,
                        modifier = Modifier.weight(1f),
                    )
                } else {
                    EsBtn(
                        text = "Rated · Thanks!",
                        onClick = {},
                        kind = EsBtnKind.Secondary,
                        full = true,
                        size = EsBtnSize.Lg,
                        disabled = true,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
            null -> Unit
        }
        if (canCancel) {
            EsBtn(
                text = "Cancel",
                onClick = onCancel,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Lg,
            )
        }
        // v2 — engineer-only "Revise quote" affordance, only while
        // working the job and only when no proposal is already pending.
        if (
            isEngineer &&
            (job.status == RepairJobStatus.EnRoute || job.status == RepairJobStatus.InProgress) &&
            pendingCostRevision == null
        ) {
            EsBtn(
                text = "Revise quote",
                onClick = onReviseQuote,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Lg,
            )
        }
    }
}

private sealed interface PrimaryCta {
    data class PlaceBid(val editing: Boolean) : PrimaryCta
    data object CheckIn : PrimaryCta
    data object MarkDone : PrimaryCta
    data object Rate : PrimaryCta
    data object RatedDone : PrimaryCta
}

// --- Sheets -----------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BidComposerSheet(
    existingBid: RepairBid?,
    placingBid: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (amountRupees: Double, etaHours: Int?, note: String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var amount by rememberSaveable(existingBid?.id) {
        // Pre-fill with Locale.US so the dot-decimal form round-trips
        // through toDoubleOrNull() regardless of device locale. On a
        // device set to a comma-decimal locale (e.g. de_DE), the bare
        // "%.0f".format would render "1.001" for 1000.5 and re-parse
        // as 1001.0, silently corrupting the bid.
        mutableStateOf(existingBid?.amountRupees?.let { String.format(java.util.Locale.US, "%.0f", it) } ?: "")
    }
    var eta by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.etaHours?.toString() ?: "")
    }
    var note by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.note.orEmpty())
    }

    var amountTouched by rememberSaveable { mutableStateOf(false) }
    var etaTouched by rememberSaveable { mutableStateOf(false) }
    // Persist focus across config-change. The two touched flags above
    // already use rememberSaveable; if focus drops to its default after
    // rotation while the touched flag remains true, the error / helper
    // text logic for these fields renders an inconsistent state.
    var amountFocused by rememberSaveable { mutableStateOf(false) }
    var etaFocused by rememberSaveable { mutableStateOf(false) }

    val parsedAmount = amount.toDoubleOrNull()
    val amountValid = bidComposerAmountValid(amount)
    val parsedEta = eta.trim().takeIf { it.isNotEmpty() }?.toIntOrNull()
    val etaValid = bidComposerEtaValid(eta)

    val amountError by remember(amount, amountTouched) {
        derivedStateOf { amountTouched && !amountValid }
    }
    val etaError by remember(eta, etaTouched) {
        derivedStateOf { etaTouched && !etaValid }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = if (existingBid != null) stringResource(R.string.repair_bidcomposer_update_title) else stringResource(R.string.repair_bidcomposer_place_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Price field
            Column {
                Text(
                    text = stringResource(R.string.repair_bidcomposer_price_label),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk700,
                    modifier = Modifier.padding(bottom = 6.dp),
                )
                OutlinedTextField(
                    value = amount,
                    // ASCII-only digits — Char.isDigit() also accepts
                    // Devanagari / Arabic codepoints which break
                    // toDoubleOrNull() downstream and leave amountValid
                    // false with no user-visible hint.
                    onValueChange = { amount = it.filter { ch -> ch in '0'..'9' || ch == '.' } },
                    placeholder = { Text("0") },
                    leadingIcon = { Text("₹", color = SevaInk500, fontSize = 16.sp) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    isError = amountError,
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SevaGreen700,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .onFocusChanged { focusState ->
                            if (!focusState.isFocused && amountFocused) amountTouched = true
                            amountFocused = focusState.isFocused
                        },
                )
                if (amountError) {
                    Text(
                        text = stringResource(R.string.repair_bidcomposer_amount_error),
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(start = 4.dp, top = 4.dp),
                    )
                }
            }
            // ETA field
            EsField(
                value = eta,
                // ASCII-only digits — same trap as the amount field.
                onChange = { eta = it.filter { ch -> ch in '0'..'9' } },
                // The old "When can you arrive? (hours)" was ambiguous —
                // engineers couldn't tell if it meant clock-hour, travel
                // time, or total job duration. Hospital-side rendering
                // ("ETA Nh") suggests *travel time from now*, so make
                // that explicit in both the label and the hint.
                label = "Travel time to site (hours from now)",
                placeholder = "e.g. 4",
                hint = "How long until you arrive — don't include the repair itself.",
                type = EsFieldType.Number,
                error = if (etaError) "Enter hours as a positive whole number" else null,
                modifier = Modifier.onFocusChanged { focusState ->
                    if (!focusState.isFocused && etaFocused) etaTouched = true
                    etaFocused = focusState.isFocused
                },
            )
            // Note field — cap at 500 chars to keep payload small and
            // the on-screen surface readable. The server side has no
            // hard limit today; without this the user can paste a wall
            // of text and the hospital UI clips it without warning.
            EsField(
                value = note,
                onChange = { note = it.take(NOTE_MAX_LEN) },
                label = "Note to hospital",
                placeholder = "Mention spare parts, prior work…",
                type = EsFieldType.Multiline,
            )
            // Info banner
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(SevaInfo50)
                    .padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Shield,
                    contentDescription = null,
                    tint = SevaInfo500,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    // "Locked once submitted" wasn't true — the same sheet
                    // re-opens as "Update your bid" when an existingBid is
                    // present, and there's a withdrawBid flow on YourBidCard.
                    // Tell engineers what they can actually do.
                    text = stringResource(R.string.repair_bidcomposer_info_body),
                    fontSize = 11.sp,
                    color = SevaInfo500,
                )
            }
            EsBtn(
                text = if (placingBid) "Submitting…" else "Submit bid",
                onClick = {
                    amountTouched = true
                    etaTouched = true
                    val value = parsedAmount
                    if (value != null && amountValid && etaValid) {
                        onSubmit(value, parsedEta, note.trim().ifBlank { null })
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = !(amountValid && etaValid) || placingBid,
            )
            EsBtn(
                text = "Cancel",
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = placingBid,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CheckinSheet(
    updating: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (List<RepairJobDetailViewModel.CompletionProofPhoto>) -> Unit,
) {
    // PR-D10 (T2.9): before-photos required at check-in. Mirrors the
    // CompletionProofSheet photo-grid pattern. 1+ photo is the minimum
    // strategy memo enforces ("photo of equipment before any work");
    // we cap at 4 to keep the upload payload sane on bad reception.
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var picked by rememberSaveable(stateSaver = UriListSaver) { mutableStateOf(emptyList<Uri>()) }
    val maxPhotos = 4

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = maxPhotos),
    ) { uris ->
        if (uris.isNotEmpty()) {
            picked = (picked + uris).distinct().take(maxPhotos)
        }
    }

    ModalBottomSheet(
        onDismissRequest = { if (!updating) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_checkin_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                text = stringResource(R.string.repair_checkin_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            Text(
                text = stringResource(R.string.repair_checkin_photos_label),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk700,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                repeat(maxPhotos) { i ->
                    val hasPhoto = i < picked.size
                    val uri = picked.getOrNull(i)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (hasPhoto) Paper2 else Color.White)
                            .border(
                                width = 1.5.dp,
                                color = if (hasPhoto) SevaGreen700 else BorderDefault,
                                shape = RoundedCornerShape(10.dp),
                            )
                            .clickable(enabled = !updating && !hasPhoto) {
                                launcher.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                )
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (hasPhoto && uri != null) {
                            AsyncImage(
                                model = uri,
                                contentDescription = null,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(10.dp)),
                                contentScale = ContentScale.Crop,
                            )
                            // Round 461: 48dp hit area (Material/WCAG
                            // touch min); visible chip stays 22dp via
                            // the inner Box. Was a fat-finger nightmare.
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(48.dp)
                                    .clickable(
                                        enabled = !updating,
                                        onClickLabel = "Remove photo",
                                        role = androidx.compose.ui.semantics.Role.Button,
                                        onClick = { picked = picked - uri },
                                    ),
                                contentAlignment = Alignment.TopEnd,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(22.dp)
                                        .padding(2.dp)
                                        .background(Color.Black.copy(alpha = 0.55f), CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(
                                        Icons.Filled.Close,
                                        contentDescription = null,
                                        tint = Color.White,
                                        modifier = Modifier.size(12.dp),
                                    )
                                }
                            }
                        } else if (i == picked.size) {
                            Icon(
                                imageVector = Icons.Filled.AddPhotoAlternate,
                                contentDescription = "Add photo",
                                tint = SevaGreen700,
                                modifier = Modifier.size(20.dp),
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Outlined.PhotoCamera,
                                contentDescription = null,
                                tint = SevaInk400,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
            EsBtn(
                text = if (updating) "Checking in…" else "I'm here · check in",
                onClick = {
                    // Round 340 — read uris on IO. Compose onClick runs on
                    // Main; up to 4 multi-MB picked photos blocking Main
                    // would trip ANR.
                    scope.launch(kotlinx.coroutines.Dispatchers.IO) {
                        val resolver = context.contentResolver
                        val photos = picked.mapNotNull { uri ->
                            val mime = resolver.getType(uri) ?: MIME_JPEG
                            val name = uri.lastPathSegment ?: "before-${System.currentTimeMillis()}.jpg"
                            val bytes = runCatching {
                                resolver.openInputStream(uri)?.use { it.readBytes() }
                            }.getOrNull() ?: return@mapNotNull null
                            RepairJobDetailViewModel.CompletionProofPhoto(
                                fileName = name,
                                mimeType = mime,
                                bytes = bytes,
                            )
                        }
                        onConfirm(photos)
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = picked.isEmpty() || updating,
            )
            EsBtn(
                text = "Cancel",
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = updating,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CompletionProofSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (List<RepairJobDetailViewModel.CompletionProofPhoto>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var picked by rememberSaveable(stateSaver = UriListSaver) { mutableStateOf(emptyList<Uri>()) }
    val maxPhotos = 4

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = maxPhotos),
    ) { uris ->
        if (uris.isNotEmpty()) {
            picked = (picked + uris).distinct().take(maxPhotos)
        }
    }

    ModalBottomSheet(
        onDismissRequest = { if (!submitting) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_markdone_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Helper text — engineers were uploading random shots and
            // dragging support questions about "did it submit?". State
            // the count cap + the why (hospital NABH/JCI compliance
            // archives consume these images) so the bar is clear before
            // the picker opens.
            Text(
                text = stringResource(R.string.repair_markdone_body, maxPhotos),
                fontSize = 12.sp,
                color = SevaInk600,
            )
            Text(
                text = stringResource(R.string.repair_markdone_photos_label),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk700,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                repeat(maxPhotos) { i ->
                    val hasPhoto = i < picked.size
                    val uri = picked.getOrNull(i)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (hasPhoto) Paper2 else Color.White)
                            .border(
                                width = 1.5.dp,
                                color = if (hasPhoto) SevaGreen700 else BorderDefault,
                                shape = RoundedCornerShape(10.dp),
                            )
                            .clickable(enabled = !submitting && !hasPhoto) {
                                launcher.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                )
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (hasPhoto && uri != null) {
                            AsyncImage(
                                model = uri,
                                contentDescription = null,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(10.dp)),
                                contentScale = ContentScale.Crop,
                            )
                            // Round 461: 48dp touch min (same fix as
                            // the update-status grid above).
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(48.dp)
                                    .clickable(
                                        enabled = !submitting,
                                        onClickLabel = "Remove photo",
                                        role = androidx.compose.ui.semantics.Role.Button,
                                        onClick = { picked = picked - uri },
                                    ),
                                contentAlignment = Alignment.TopEnd,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(22.dp)
                                        .padding(2.dp)
                                        .background(Color.Black.copy(alpha = 0.55f), CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(
                                        Icons.Filled.Close,
                                        contentDescription = null,
                                        tint = Color.White,
                                        modifier = Modifier.size(12.dp),
                                    )
                                }
                            }
                        } else if (i == picked.size) {
                            Icon(
                                imageVector = Icons.Filled.AddPhotoAlternate,
                                contentDescription = "Add photo",
                                tint = SevaGreen700,
                                modifier = Modifier.size(20.dp),
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Outlined.PhotoCamera,
                                contentDescription = null,
                                tint = SevaInk400,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
            // "Work summary" multiline field used to live here, but the
            // sheet's onSubmit + submitCompletionProof both took only
            // photos — the typed text was discarded. Removed until a
            // real work_summary column ships and submitCompletionProof
            // can carry it through.
            EsBtn(
                text = if (submitting) "Saving…" else "Mark done",
                onClick = {
                    // Round 340 — read uris on IO. Compose onClick runs on
                    // Main; up to 4 multi-MB picked photos blocking Main
                    // would trip ANR.
                    scope.launch(kotlinx.coroutines.Dispatchers.IO) {
                        val resolver = context.contentResolver
                        val photos = picked.mapNotNull { uri ->
                            val mime = resolver.getType(uri) ?: MIME_JPEG
                            val name = uri.lastPathSegment ?: "after-${System.currentTimeMillis()}.jpg"
                            val bytes = runCatching {
                                resolver.openInputStream(uri)?.use { it.readBytes() }
                            }.getOrNull() ?: return@mapNotNull null
                            RepairJobDetailViewModel.CompletionProofPhoto(
                                fileName = name,
                                mimeType = mime,
                                bytes = bytes,
                            )
                        }
                        onSubmit(photos)
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = picked.isEmpty() || submitting,
            )
            EsBtn(
                text = "Cancel",
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = submitting,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RateSheet(
    job: RepairJob,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (Int, String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val existing = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating
        RepairJobDetailViewModel.ViewerRole.Other -> null
    }
    var rating by rememberSaveable(existing) { mutableIntStateOf(existing ?: 0) }
    var note by rememberSaveable { mutableStateOf("") }
    val labels = listOf("Poor", "Fair", "Good", "Great", "Excellent")
    val sheetTitle = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Engineer -> "Rate hospital"
        else -> "Rate engineer"
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = sheetTitle,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                (1..5).forEach { n ->
                    val filled = n <= rating
                    Box(
                        // Round 448 — onClickLabel + Role.Button so TalkBack
                        // announces "Rate $n stars, button" instead of just
                        // "$n star" + a system "double-tap to activate"
                        // hint. The icon's contentDescription still carries
                        // the filled / outline visual; the click semantics
                        // describe the action.
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .clickable(
                                enabled = existing == null && !submitting,
                                onClickLabel = "Rate $n out of 5 stars",
                                role = androidx.compose.ui.semantics.Role.Button,
                            ) {
                                rating = n
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                            contentDescription = "$n star",
                            tint = if (filled) WarnGold else SevaInk300,
                            modifier = Modifier.size(36.dp),
                        )
                    }
                }
            }
            Text(
                text = if (rating == 0) stringResource(R.string.repair_rate_tap_to_rate) else labels[rating - 1],
                fontSize = 13.sp,
                color = SevaInk500,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            EsField(
                value = note,
                // 500 char cap mirrors the cancellation-reason field
                // bound (round 234) — keeps a paste-bomb from writing
                // an unbounded essay to job_ratings.notes.
                onChange = { v -> note = if (v.length > 500) v.take(500) else v },
                label = "Notes (optional)",
                placeholder = "What stood out?",
                type = EsFieldType.Multiline,
            )
            EsBtn(
                text = if (submitting) "Submitting…" else "Submit rating",
                onClick = { onSubmit(rating, note.trim().ifBlank { null }) },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = rating == 0 || submitting,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CancelSheet(
    updating: Boolean,
    jobStatus: RepairJobStatus?,
    escrowHeldRupees: Int?,
    onDismiss: () -> Unit,
    onConfirm: (String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // Reason is now plumbed through cancelJob → updateStatus → the new
    // repair_jobs.cancellation_reason column (PR #614 migration). Empty
    // reason is allowed for `requested` (no engineer to inform), but
    // required once an engineer has been assigned / is en route / has
    // started — they deserve to know why the job vanished.
    var reason by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableStateOf("") }
    val isAssignedOrLater = jobStatus in setOf(
        RepairJobStatus.Assigned,
        RepairJobStatus.EnRoute,
        RepairJobStatus.InProgress,
    )
    val reasonRequired = isAssignedOrLater
    val reasonOk = !reasonRequired || reason.trim().length >= 10
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_cancel_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Status-aware warning. After accept_repair_bid the engineer
            // may already be traveling — be honest about that. If money
            // is in escrow, surface the refund expectation in the same
            // breath so the hospital doesn't have to chase support.
            Text(
                text = when {
                    isAssignedOrLater ->
                        stringResource(R.string.repair_cancel_body_assigned)
                    else ->
                        stringResource(R.string.repair_cancel_body_default)
                },
                fontSize = 13.sp,
                color = SevaInk600,
            )
            if (escrowHeldRupees != null) {
                Text(
                    text = stringResource(R.string.repair_cancel_escrow_refund, escrowHeldRupees),
                    fontSize = 12.sp,
                    color = SevaInk700,
                )
            }
            androidx.compose.material3.OutlinedTextField(
                value = reason,
                onValueChange = { reason = it.take(500) },
                label = {
                    Text(if (reasonRequired) stringResource(R.string.repair_cancel_reason_required_label) else stringResource(R.string.delete_account_sheet_reason_label))
                },
                placeholder = { Text(stringResource(R.string.repair_cancel_reason_placeholder)) },
                isError = reasonRequired && reason.isNotEmpty() && !reasonOk,
                minLines = 2,
                maxLines = 5,
                enabled = !updating,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                EsBtn(
                    text = "Keep job",
                    onClick = onDismiss,
                    kind = EsBtnKind.Secondary,
                    full = true,
                    disabled = updating,
                    modifier = Modifier.weight(1f),
                )
                EsBtn(
                    text = if (updating) "Cancelling…" else "Cancel job",
                    onClick = { onConfirm(reason.trim().ifBlank { null }) },
                    kind = EsBtnKind.Danger,
                    full = true,
                    disabled = updating || !reasonOk,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

// --- Misc helpers -----------------------------------------------------------

@Composable
private fun QueuedOutboxPill(bidCount: Int, statusCount: Int) {
    if (bidCount <= 0 && statusCount <= 0) return
    val parts = buildList {
        if (bidCount > 0) add(if (bidCount == 1) "1 bid" else "$bidCount bids")
        if (statusCount > 0) add(if (statusCount == 1) "1 status change" else "$statusCount status changes")
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CheckCircle,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = stringResource(R.string.repair_queued_outbox_body, parts.joinToString(" + ")),
            fontSize = 12.sp,
            color = SevaInk900,
        )
    }
}

@Composable
private fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.repair_notfound_body),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        EsBtn(text = "Back", onClick = onBack, kind = EsBtnKind.Primary)
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ErrorBanner(message = message)
        EsBtn(text = "Retry", onClick = onRetry, kind = EsBtnKind.Primary)
    }
}

private fun initialsOf(name: String): String = repairDetailInitials(name)

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

private val UriListSaver = androidx.compose.runtime.saveable.listSaver<List<Uri>, String>(
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
        subtitle = "Pay ${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
            "into escrow to release the engineer to start work.",
    )
    escrow.isHeld -> EscrowStatusCopy(
        label = "Funds in escrow",
        subtitle = "${com.equipseva.app.core.util.formatRupees(escrow.amountRupees)} " +
            "is held by EquipSeva. Auto-released to engineer 48h after completion.",
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

@Composable
private fun EngineerPayoutStatusCard(
    p: com.equipseva.app.core.data.payouts.JobPayoutStatus,
    isHospital: Boolean,
    // Round 437 fix #2 — engineer-side recovery CTA when status=Failed.
    // Hospital side passes null because they can't fix the engineer's
    // UPI. Default null so existing callers (none beyond this file)
    // get the no-CTA shape.
    onOpenPayoutMethod: (() -> Unit)? = null,
) {
    val rupees = p.amountPaise / 100.0
    val accent = when (p.status) {
        com.equipseva.app.core.data.payouts.PayoutStatus.Processed -> SevaGreen700
        com.equipseva.app.core.data.payouts.PayoutStatus.Failed -> SevaDanger500
        else -> SevaWarning500
    }
    val bg = when (p.status) {
        com.equipseva.app.core.data.payouts.PayoutStatus.Processed -> SevaGreen50
        else -> SevaWarning50
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .border(width = 1.dp, color = accent, shape = RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Text(
            engineerPayoutTitle(p, isHospital),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.repair_payout_amount, String.format(java.util.Locale.ENGLISH, "%.2f", rupees)),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = SevaInk900,
        )
        val sub = engineerPayoutSubtitle(p, isHospital)
        if (sub != null) {
            Spacer(Modifier.height(4.dp))
            Text(sub, fontSize = 13.sp, color = SevaInk500)
        }
        if (!p.utr.isNullOrBlank() && p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Processed) {
            Spacer(Modifier.height(2.dp))
            Text(
                stringResource(R.string.repair_payout_utr, p.utr),
                fontSize = 12.sp,
                color = SevaGreen700,
                fontWeight = FontWeight.Medium,
            )
        }
        if (!p.failureReason.isNullOrBlank() &&
            (p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed ||
                p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Cancelled)
        ) {
            Spacer(Modifier.height(2.dp))
            Text(
                p.failureReason.orEmpty(),
                fontSize = 12.sp,
                color = if (p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed) SevaDanger500 else SevaInk500,
            )
        }
        // Round 437 fix #2 — engineer self-recovery affordance on
        // Failed payout. Hospital side has onOpenPayoutMethod=null
        // and therefore never sees this button.
        if (onOpenPayoutMethod != null &&
            p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed
        ) {
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = "Update payout method",
                onClick = onOpenPayoutMethod,
                kind = EsBtnKind.Primary,
            )
        }
    }
}

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
