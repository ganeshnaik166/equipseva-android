package com.equipseva.app.features.repair

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StepperStep
import com.equipseva.app.designsystem.components.VerticalStepper
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.repair.components.iconForEquipment
import com.equipseva.app.features.repair.components.toTone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onOpenChat: (String) -> Unit,
    viewModel: RepairJobDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var withdrawConfirmOpen by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
    }
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is RepairJobDetailViewModel.Effect.NavigateToChat -> onOpenChat(effect.conversationId)
            }
        }
    }

    Scaffold(
        containerColor = com.equipseva.app.designsystem.theme.PaperDefault,
        topBar = {
            com.equipseva.app.designsystem.components.EsTopBar(
                title = state.job?.jobNumber ?: "Repair request",
                onBack = onBack,
                right = {
                    if (state.canReport) {
                        var menuOpen by rememberSaveable { mutableStateOf(false) }
                        Box {
                            IconButton(onClick = { menuOpen = true }) {
                                Icon(
                                    imageVector = Icons.Filled.MoreVert,
                                    contentDescription = "More",
                                    tint = com.equipseva.app.designsystem.theme.SevaInk900,
                                )
                            }
                            DropdownMenu(
                                expanded = menuOpen,
                                onDismissRequest = { menuOpen = false },
                            ) {
                                DropdownMenuItem(
                                    text = { Text("Report job") },
                                    onClick = {
                                        menuOpen = false
                                        viewModel.onOpenReport()
                                    },
                                )
                            }
                        }
                    }
                },
            )
        },
        bottomBar = {
            val job = state.job
            // Hospital viewer has no bid CTA — they accept bids inline from
            // the bids-received section, not from a sticky footer.
            if (job != null && state.viewerRole != RepairJobDetailViewModel.ViewerRole.Hospital) {
                StickyBottomBar(
                    job = job,
                    ownBid = state.ownBid,
                    withdrawing = state.withdrawingBid,
                    openingChat = state.openingChat,
                    onMessageHospital = viewModel::openChatWithHospital,
                    onPlaceBid = viewModel::openBidComposer,
                    onWithdraw = { withdrawConfirmOpen = true },
                )
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            QueuedOutboxPill(
                bidCount = state.queuedBidCount,
                statusCount = state.queuedStatusCount,
            )
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
                    updatingStatus = state.updatingStatus,
                    submittingRating = state.submittingRating,
                    acceptingBidId = state.acceptingBidId,
                    openingChat = state.openingChat,
                    afterPhotoSignedUrls = state.afterPhotoSignedUrls,
                    onCheckIn = viewModel::checkIn,
                    onMarkDone = viewModel::openProofSheet,
                    onCancelJob = viewModel::cancelJob,
                    onSubmitRating = viewModel::submitRating,
                    onAcceptBid = viewModel::acceptBid,
                    onMessageEngineer = viewModel::openChatWithEngineer,
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

    if (state.reportingTargetId != null) {
        ReportContentSheet(
            titleLabel = "Report this repair job",
            submitting = state.submittingReport,
            onDismiss = viewModel::onDismissReport,
            onSubmit = viewModel::onSubmitReport,
        )
    }

    if (withdrawConfirmOpen) {
        AlertDialog(
            onDismissRequest = {
                if (!state.withdrawingBid) withdrawConfirmOpen = false
            },
            title = { Text("Withdraw this bid?") },
            text = { Text("The hospital will no longer see your quote. You can re-bid while the job is still open.") },
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
                ) { Text("Withdraw") }
            },
            dismissButton = {
                TextButton(
                    enabled = !state.withdrawingBid,
                    onClick = { withdrawConfirmOpen = false },
                ) { Text("Keep bid") }
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
    updatingStatus: Boolean,
    submittingRating: Boolean,
    acceptingBidId: String?,
    openingChat: Boolean,
    afterPhotoSignedUrls: List<String>,
    onCheckIn: () -> Unit,
    onMarkDone: () -> Unit,
    onCancelJob: () -> Unit,
    onSubmitRating: (Int, String?) -> Unit,
    onAcceptBid: (String) -> Unit,
    onMessageEngineer: () -> Unit,
) {
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val canHospitalCancel = isHospital && job.status in setOf(
        RepairJobStatus.Requested,
        RepairJobStatus.Assigned,
    )
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = Spacing.xl),
    ) {
        EquipmentBannerCard(
            job = job,
            hospitalName = hospitalName.takeIf { !isHospital },
            hospitalLocation = hospitalLocation.takeIf { !isHospital },
        )

        if (viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer) {
            EngineerActionStrip(
                job = job,
                updatingStatus = updatingStatus,
                onCheckIn = onCheckIn,
                onMarkDone = onMarkDone,
            )
        }

        SectionHeader(title = "Issue described")
        IssueCard(job = job)

        SectionHeader(title = "Location")
        LocationCard(
            siteLocation = job.siteLocation,
            siteLatitude = job.siteLatitude,
            siteLongitude = job.siteLongitude,
            // Engineer sees the real address + a Navigate CTA only after a
            // bid is accepted (job.isAssignedToEngineer). Other roles either
            // already know it (hospital posted it) or aren't entitled.
            revealAddressForEngineer = job.isAssignedToEngineer,
            viewerRole = viewerRole,
        )

        if (isHospital) {
            SectionHeader(title = "Bids received")
            HospitalBidsList(
                job = job,
                bids = bids,
                engineerNames = engineerNames,
                acceptingBidId = acceptingBidId,
                openingChat = openingChat,
                onAcceptBid = onAcceptBid,
                onMessageEngineer = onMessageEngineer,
            )
        } else {
            SectionHeader(title = "Your bid")
            YourBidCard(ownBid = ownBid)
        }

        SectionHeader(title = "Status")
        StatusStepperCard(job = job)

        if (afterPhotoSignedUrls.isNotEmpty()) {
            SectionHeader(title = "Completion proof")
            CompletionProofGallery(urls = afterPhotoSignedUrls)
        }

        if (job.status == RepairJobStatus.Completed &&
            viewerRole != RepairJobDetailViewModel.ViewerRole.Other
        ) {
            SectionHeader(title = "Rate this job")
            RatingCard(
                job = job,
                viewerRole = viewerRole,
                submitting = submittingRating,
                onSubmit = onSubmitRating,
            )
        }

        if (canHospitalCancel) {
            CancelJobSection(
                updating = updatingStatus,
                onConfirm = onCancelJob,
            )
        }
    }
}

@Composable
private fun CancelJobSection(
    updating: Boolean,
    onConfirm: () -> Unit,
) {
    var confirmOpen by rememberSaveable { mutableStateOf(false) }
    Box(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.md)
            .fillMaxWidth(),
        contentAlignment = Alignment.Center,
    ) {
        TextButton(
            onClick = { confirmOpen = true },
            enabled = !updating,
        ) {
            Text(
                text = if (updating) "Cancelling…" else "Cancel this job",
                color = MaterialTheme.colorScheme.error,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
    if (confirmOpen) {
        AlertDialog(
            onDismissRequest = { confirmOpen = false },
            title = { Text("Cancel this job?") },
            text = {
                Text(
                    "The engineer will be notified. You can post a new request later if you still need help.",
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmOpen = false
                        onConfirm()
                    },
                ) {
                    Text(
                        text = "Cancel job",
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmOpen = false }) {
                    Text("Keep it")
                }
            },
        )
    }
}

@Composable
private fun EngineerActionStrip(
    job: RepairJob,
    updatingStatus: Boolean,
    onCheckIn: () -> Unit,
    onMarkDone: () -> Unit,
) {
    val canCheckIn = job.status == RepairJobStatus.Assigned ||
        job.status == RepairJobStatus.EnRoute
    val canMarkDone = job.status == RepairJobStatus.InProgress ||
        job.status == RepairJobStatus.EnRoute
    if (!canCheckIn && !canMarkDone) return
    val shape = MaterialTheme.shapes.medium
    Row(
        modifier = Modifier
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .fillMaxWidth()
            .background(BrandGreen50, shape)
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (canCheckIn) {
            Button(
                onClick = onCheckIn,
                enabled = !updatingStatus,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Icon(Icons.Outlined.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (updatingStatus) "Checking in…" else "Check in")
            }
        }
        if (canMarkDone) {
            Button(
                onClick = onMarkDone,
                enabled = !updatingStatus,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.secondary,
                    contentColor = MaterialTheme.colorScheme.onSecondary,
                ),
            ) {
                Icon(Icons.Outlined.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (updatingStatus) "Saving…" else "Mark done")
            }
        }
    }
}

@Composable
private fun RatingCard(
    job: RepairJob,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    submitting: Boolean,
    onSubmit: (Int, String?) -> Unit,
) {
    val shape = MaterialTheme.shapes.medium
    val existing = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating
        RepairJobDetailViewModel.ViewerRole.Other -> null
    }
    val existingReview = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalReview
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerReview
        RepairJobDetailViewModel.ViewerRole.Other -> null
    }

    var stars by rememberSaveable(existing) { mutableStateOf(existing ?: 0) }
    var review by rememberSaveable(existingReview) {
        mutableStateOf(existingReview.orEmpty())
    }
    val prompt = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> "How did the engineer do?"
        RepairJobDetailViewModel.ViewerRole.Engineer -> "How was this customer?"
        RepairJobDetailViewModel.ViewerRole.Other -> ""
    }

    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.md)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = prompt,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink900,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            (1..5).forEach { n ->
                val filled = n <= stars
                IconButton(
                    onClick = { if (existing == null) stars = n },
                    enabled = existing == null && !submitting,
                    modifier = Modifier.size(36.dp),
                ) {
                    Icon(
                        imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                        contentDescription = "$n star",
                        tint = if (filled) Color(0xFFF5A623) else Ink500,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
        }
        if (existing == null) {
            OutlinedTextField(
                value = review,
                onValueChange = { review = it },
                label = { Text("Leave a note (optional)") },
                maxLines = 4,
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
            )
            PrimaryButton(
                label = if (submitting) "Submitting…" else "Submit rating",
                onClick = { onSubmit(stars, review.trim().ifBlank { null }) },
                enabled = stars in 1..5 && !submitting,
                loading = submitting,
            )
        } else {
            Text(
                text = "Thanks — your rating is locked in.",
                fontSize = 13.sp,
                color = Ink700,
            )
            if (!existingReview.isNullOrBlank()) {
                Text(
                    text = "\"$existingReview\"",
                    fontSize = 13.sp,
                    color = Ink500,
                )
            }
        }
    }
}

@Composable
private fun EquipmentBannerCard(job: RepairJob, hospitalName: String?, hospitalLocation: String?) {
    val shape = MaterialTheme.shapes.medium
    val isDark = isSystemInDarkTheme()
    val bannerGradient = if (isDark) {
        listOf(Color(0xFF1F2A26), Color(0xFF18211E))
    } else {
        listOf(Color(0xFFF2F6F4), Color(0xFFE7EEEB))
    }
    val pillBg = if (isDark) Color(0xCC1B1F26) else Color(0xD9FFFFFF)
    val pillBorder = if (isDark) Color(0x662E8B6E) else Color(0x260B6E4F)
    Column(
        modifier = Modifier
            .padding(Spacing.lg)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape),
    ) {
        // Banner — simple tinted surface with centered equipment pill.
        // Fallback layout used in place of diagonal-line pattern (see deviation notes).
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .background(
                    brush = Brush.verticalGradient(colors = bannerGradient),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Row(
                modifier = Modifier
                    .background(pillBg, RoundedCornerShape(8.dp))
                    .border(1.dp, pillBorder, RoundedCornerShape(8.dp))
                    .padding(horizontal = 18.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val (hue, icon) = iconForEquipment(job)
                GradientTile(icon = icon, hue = hue, size = 28.dp)
                Text(
                    text = job.equipmentCategory.displayName.uppercase(),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.sp,
                    color = Ink700,
                )
            }
        }
        Column(modifier = Modifier.padding(Spacing.md)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = job.equipmentLabel,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                if (job.urgency != RepairJobUrgency.Unknown) {
                    StatusChip(
                        label = job.urgency.displayName,
                        tone = job.urgency.toTone(),
                    )
                }
            }
            val modelLine = listOfNotNull(job.equipmentBrand, job.equipmentModel)
                .joinToString(" ")
                .ifBlank { null }
            if (modelLine != null && modelLine != job.equipmentLabel) {
                Text(
                    text = modelLine,
                    fontSize = 13.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            val postedLine = buildString {
                job.createdAtInstant?.let { posted ->
                    append("Posted ${relativeLabel(posted)} ago")
                }
                if (!hospitalName.isNullOrBlank()) {
                    if (isNotEmpty()) append(" · ")
                    append("by ").append(hospitalName)
                }
            }
            if (postedLine.isNotBlank()) {
                Text(
                    text = postedLine,
                    fontSize = 12.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            if (!hospitalLocation.isNullOrBlank()) {
                Text(
                    text = hospitalLocation,
                    fontSize = 12.sp,
                    color = Ink500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            val schedule = listOfNotNull(job.scheduledDate, job.scheduledTimeSlot).joinToString(" ")
            if (schedule.isNotBlank()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(top = 10.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.LocationOn,
                        contentDescription = null,
                        tint = BrandGreen,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = schedule,
                        fontSize = 13.sp,
                        color = Ink700,
                    )
                }
            }
            job.estimatedCostRupees?.let { budget ->
                Text(
                    text = "Budget ~ ${formatRupees(budget)}",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink700,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }
}

@Composable
private fun IssueCard(job: RepairJob) {
    val shape = MaterialTheme.shapes.medium
    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.md),
    ) {
        Text(
            text = job.issueDescription,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            color = Ink900,
        )
    }
}

@Composable
private fun LocationCard(
    siteLocation: String?,
    siteLatitude: Double?,
    siteLongitude: Double?,
    revealAddressForEngineer: Boolean,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
) {
    val shape = MaterialTheme.shapes.medium
    val context = LocalContext.current
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    // Engineer can see + navigate once they're assigned. Hospital always sees
    // the address they typed. Other roles get a generic placeholder.
    val canShowAddress = !siteLocation.isNullOrBlank() &&
        (isHospital || (isEngineer && revealAddressForEngineer))
    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(
                imageVector = Icons.Outlined.LocationOn,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = "Service site",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink700,
            )
        }
        if (canShowAddress) {
            Text(
                text = siteLocation!!,
                fontSize = 14.sp,
                color = Ink900,
                fontWeight = FontWeight.SemiBold,
            )
            // Engineer-only Navigate CTA. Hospitals already know where they
            // are; the button would be visual noise for them.
            if (isEngineer) {
                OutlinedButton(
                    onClick = {
                        // Prefer geo:lat,lng?q=lat,lng(label) when the
                        // hospital pinned a marker — Maps opens straight to
                        // the dropped pin instead of guessing from the text
                        // address. Falls back to geo:0,0?q=<address> when
                        // only the free-text label exists (legacy rows or
                        // engineer signed up before the picker landed).
                        val encoded = Uri.encode(siteLocation)
                        val uri = if (siteLatitude != null && siteLongitude != null) {
                            val label = Uri.encode("Service site")
                            Uri.parse("geo:$siteLatitude,$siteLongitude?q=$siteLatitude,$siteLongitude($label)")
                        } else {
                            Uri.parse("geo:0,0?q=$encoded")
                        }
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uri)
                        try {
                            context.startActivity(intent)
                        } catch (_: android.content.ActivityNotFoundException) {
                            val fallbackUrl = if (siteLatitude != null && siteLongitude != null) {
                                "https://www.google.com/maps/dir/?api=1&destination=$siteLatitude,$siteLongitude"
                            } else {
                                "https://www.google.com/maps/dir/?api=1&destination=$encoded"
                            }
                            val fallback = android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                Uri.parse(fallbackUrl),
                            )
                            try { context.startActivity(fallback) } catch (_: Throwable) {}
                        }
                    },
                ) {
                    Icon(
                        imageVector = Icons.Outlined.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text("Navigate to site")
                }
            }
        } else {
            Text(
                text = if (isEngineer)
                    "Full address shows up after the hospital accepts your bid."
                else
                    "Address will be shared once the bid is accepted.",
                fontSize = 13.sp,
                color = Ink700,
            )
        }
    }
}

@Composable
private fun HospitalBidsList(
    job: RepairJob,
    bids: List<RepairBid>,
    engineerNames: Map<String, String>,
    acceptingBidId: String?,
    openingChat: Boolean,
    onAcceptBid: (String) -> Unit,
    onMessageEngineer: () -> Unit,
) {
    val shape = MaterialTheme.shapes.medium
    if (bids.isEmpty()) {
        Column(
            modifier = Modifier
                .padding(horizontal = Spacing.lg)
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface, shape)
                .border(1.dp, Surface200, shape)
                .padding(Spacing.md),
        ) {
            Text(
                text = "No bids yet. Engineers will be notified when your job is posted.",
                fontSize = 13.sp,
                color = Ink500,
            )
        }
        return
    }
    val canAccept = job.status == RepairJobStatus.Requested
    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        bids.forEach { bid ->
            HospitalBidRow(
                bid = bid,
                engineerName = engineerNames[bid.engineerUserId],
                canAccept = canAccept,
                accepting = acceptingBidId == bid.id,
                anyAccepting = acceptingBidId != null,
                openingChat = openingChat,
                onAcceptBid = onAcceptBid,
                onMessageEngineer = onMessageEngineer,
            )
        }
    }
}

@Composable
private fun HospitalBidRow(
    bid: RepairBid,
    engineerName: String?,
    canAccept: Boolean,
    accepting: Boolean,
    anyAccepting: Boolean,
    openingChat: Boolean,
    onAcceptBid: (String) -> Unit,
    onMessageEngineer: () -> Unit,
) {
    val shape = MaterialTheme.shapes.medium
    val isAccepted = bid.status == RepairBidStatus.Accepted
    val bg = if (isAccepted) BrandGreen50 else MaterialTheme.colorScheme.surface
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(bg, shape)
            .border(1.dp, if (isAccepted) BrandGreen else Surface200, shape)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = engineerName ?: "Engineer",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink700,
                )
                Text(
                    text = formatRupees(bid.amountRupees),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isAccepted) BrandGreenDark else Ink900,
                )
            }
            StatusChip(
                label = bid.status.displayName,
                tone = bid.status.toTone(),
            )
        }
        bid.createdAtInstant?.let { placed ->
            Text(
                text = "Placed ${relativeLabel(placed)} ago",
                fontSize = 12.sp,
                color = Ink500,
            )
        }
        val meta = buildString {
            bid.etaHours?.let { append("ETA ${it}h") }
            if (isNotEmpty() && !bid.note.isNullOrBlank()) append(" · ")
            if (!bid.note.isNullOrBlank()) append(bid.note)
        }
        if (meta.isNotBlank()) {
            Text(
                text = meta,
                fontSize = 13.sp,
                color = Ink700,
            )
        }
        if (canAccept && bid.status == RepairBidStatus.Pending) {
            Button(
                onClick = { onAcceptBid(bid.id) },
                enabled = !anyAccepting,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Text(if (accepting) "Accepting…" else "Accept bid")
            }
        }
        if (isAccepted) {
            OutlinedButton(
                onClick = onMessageEngineer,
                enabled = !openingChat,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .fillMaxWidth(),
            ) {
                Icon(
                    imageVector = Icons.Outlined.ChatBubbleOutline,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(if (openingChat) "Opening…" else "Message engineer")
            }
        }
    }
}

@Composable
private fun YourBidCard(ownBid: RepairBid?) {
    val shape = MaterialTheme.shapes.medium
    if (ownBid == null) {
        Column(
            modifier = Modifier
                .padding(horizontal = Spacing.lg)
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface, shape)
                .border(1.dp, Surface200, shape)
                .padding(Spacing.md),
        ) {
            Text(
                text = "You haven't placed a bid on this job yet.",
                fontSize = 13.sp,
                color = Ink500,
            )
        }
    } else {
        Column(
            modifier = Modifier
                .padding(horizontal = Spacing.lg)
                .fillMaxWidth()
                .background(BrandGreen50, shape)
                .padding(Spacing.md),
        ) {
            Text(
                text = "Your bid",
                fontSize = 13.sp,
                color = Ink500,
            )
            Text(
                text = buildString {
                    append(formatRupees(ownBid.amountRupees))
                    ownBid.etaHours?.let { append(" · ETA ${it}h") }
                },
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = BrandGreenDark,
                modifier = Modifier.padding(top = 2.dp),
            )
            Text(
                text = "Status: ${ownBid.status.displayName}",
                fontSize = 12.sp,
                color = Ink700,
                modifier = Modifier.padding(top = 4.dp),
            )
            if (!ownBid.note.isNullOrBlank()) {
                Text(
                    text = "Note: ${ownBid.note}",
                    fontSize = 12.sp,
                    color = Ink700,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun StatusStepperCard(job: RepairJob) {
    val shape = MaterialTheme.shapes.medium
    val onSiteTime = job.startedAtInstant?.let { "${relativeLabel(it)} ago" }
    val completedTime = job.completedAtInstant?.let { "${relativeLabel(it)} ago" }
    val steps = listOf(
        StepperStep(title = "Open · awaiting bids"),
        StepperStep(title = "Bids received"),
        StepperStep(title = "Accepted"),
        StepperStep(title = "En route"),
        StepperStep(title = "On site", time = onSiteTime),
        StepperStep(title = "Completed", time = completedTime),
    )
    val current = when (job.status) {
        RepairJobStatus.Requested -> 0
        RepairJobStatus.Assigned -> 2
        RepairJobStatus.EnRoute -> 3
        RepairJobStatus.InProgress -> 4
        RepairJobStatus.Completed -> 5
        RepairJobStatus.Cancelled, RepairJobStatus.Disputed, RepairJobStatus.Unknown -> -1
    }
    Column(
        modifier = Modifier
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.md),
    ) {
        VerticalStepper(steps = steps, current = current)
    }
}

@Composable
private fun StickyBottomBar(
    job: RepairJob,
    ownBid: RepairBid?,
    withdrawing: Boolean,
    openingChat: Boolean,
    onMessageHospital: () -> Unit,
    onPlaceBid: () -> Unit,
    onWithdraw: () -> Unit,
) {
    val acceptsBids = job.status == RepairJobStatus.Requested
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(Spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (job.hospitalUserId != null) {
                OutlinedButton(
                    onClick = onMessageHospital,
                    enabled = !openingChat,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text(if (openingChat) "Opening…" else "Message")
                }
            }
            when {
                !acceptsBids -> Box(
                    modifier = Modifier.weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Bidding closed",
                        fontSize = 13.sp,
                        color = Ink500,
                    )
                }
                ownBid == null -> Button(
                    onClick = onPlaceBid,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) { Text("Place bid") }
                ownBid.status == RepairBidStatus.Pending -> Button(
                    onClick = onPlaceBid,
                    enabled = !withdrawing,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) { Text("Edit bid") }
                else -> Box(
                    modifier = Modifier.weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Bid ${ownBid.status.displayName.lowercase()}",
                        fontSize = 13.sp,
                        color = Ink500,
                    )
                }
            }
        }
        if (ownBid?.status == RepairBidStatus.Pending) {
            TextButton(
                onClick = onWithdraw,
                enabled = !withdrawing,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .fillMaxWidth(),
            ) {
                Text(if (withdrawing) "Withdrawing…" else "Withdraw bid")
            }
        }
    }
}

@Composable
private fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "This repair job is no longer available.",
            style = MaterialTheme.typography.titleMedium,
        )
        Button(onClick = onBack) { Text("Back") }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ErrorBanner(message = message)
        Button(onClick = onRetry) { Text("Retry") }
    }
}

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
        mutableStateOf(existingBid?.amountRupees?.let { "%.0f".format(it) } ?: "")
    }
    var eta by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.etaHours?.toString() ?: "")
    }
    var note by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.note.orEmpty())
    }

    var amountTouched by rememberSaveable { mutableStateOf(false) }
    var etaTouched by rememberSaveable { mutableStateOf(false) }
    var amountFocused by remember { mutableStateOf(false) }
    var etaFocused by remember { mutableStateOf(false) }

    val parsedAmount = amount.toDoubleOrNull()
    val amountValid = parsedAmount != null && parsedAmount > 0.0
    val parsedEta = eta.trim().takeIf { it.isNotEmpty() }?.toIntOrNull()
    val etaValid = eta.trim().isEmpty() || (parsedEta != null && parsedEta > 0)

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
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = if (existingBid != null) "Update your bid" else "Place your bid",
                style = MaterialTheme.typography.titleLarge,
            )

            // Branded "YOUR PRICE" pill — matches design `screens-repair.jsx
            // PlaceBidSheet`. The amount field reads as the primary action;
            // ETA + note stay below as secondary details.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(16.dp))
                    .background(com.equipseva.app.designsystem.theme.BrandGreen50)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "YOUR PRICE",
                    fontSize = 11.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    color = com.equipseva.app.designsystem.theme.BrandGreenDark,
                    letterSpacing = 1.2.sp,
                )
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
                    placeholder = { Text("0", style = MaterialTheme.typography.headlineLarge) },
                    leadingIcon = {
                        Text(
                            text = "₹",
                            style = MaterialTheme.typography.headlineMedium,
                            color = com.equipseva.app.designsystem.theme.BrandGreenDark,
                        )
                    },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    isError = amountError,
                    textStyle = MaterialTheme.typography.headlineMedium.copy(
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .onFocusChanged { focusState ->
                            if (!focusState.isFocused && amountFocused) amountTouched = true
                            amountFocused = focusState.isFocused
                        },
                )
                Text(
                    text = "Market range: ₹2,800 – ₹4,500 for similar jobs",
                    fontSize = 12.sp,
                    color = com.equipseva.app.designsystem.theme.Ink700,
                )
                if (amountError) {
                    Text(
                        text = "Enter a valid amount",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            OutlinedTextField(
                value = eta,
                onValueChange = { eta = it.filter(Char::isDigit) },
                label = { Text("ETA hours (optional)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                isError = etaError,
                supportingText = {
                    if (etaError) Text("Enter hours as a positive whole number")
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .onFocusChanged { focusState ->
                        if (!focusState.isFocused && etaFocused) etaTouched = true
                        etaFocused = focusState.isFocused
                    },
            )

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("Note (optional)") },
                maxLines = 4,
                modifier = Modifier.fillMaxWidth(),
            )

            PrimaryButton(
                label = if (placingBid) "Submitting…" else "Submit",
                onClick = {
                    amountTouched = true
                    etaTouched = true
                    val value = parsedAmount
                    if (value != null && amountValid && etaValid) {
                        onSubmit(value, parsedEta, note.trim().ifBlank { null })
                    }
                },
                enabled = amountValid && etaValid && !placingBid,
                loading = placingBid,
            )

            TextButton(
                onClick = onDismiss,
                enabled = !placingBid,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Cancel")
            }
        }
    }
}

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
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .clip(RoundedCornerShape(12.dp))
            .background(BrandGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = "${parts.joinToString(" + ")} queued — will sync when back online",
            style = MaterialTheme.typography.bodySmall,
            color = Ink900,
        )
    }
}

@Composable
private fun CompletionProofGallery(urls: List<String>) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(vertical = 4.dp),
    ) {
        items(urls, key = { it }) { url ->
            AsyncImage(
                model = url,
                contentDescription = "Completion photo",
                modifier = Modifier
                    .size(96.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Surface200),
                contentScale = ContentScale.Crop,
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
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = "Mark this job done",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = Ink900,
            )
            Text(
                text = "Add up to $maxPhotos photos so the hospital can see the work. You can skip if you really need to.",
                fontSize = 13.sp,
                color = Ink500,
            )

            // Picked previews + add tile
            LazyRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 4.dp),
            ) {
                items(picked, key = { it.toString() }) { uri ->
                    Box(
                        modifier = Modifier
                            .size(96.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Surface200),
                    ) {
                        AsyncImage(
                            model = uri,
                            contentDescription = null,
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(10.dp)),
                            contentScale = ContentScale.Crop,
                        )
                        IconButton(
                            onClick = { picked = picked - uri },
                            enabled = !submitting,
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .size(24.dp)
                                .padding(2.dp)
                                .background(Color.Black.copy(alpha = 0.55f), CircleShape),
                        ) {
                            Icon(
                                Icons.Filled.Close,
                                contentDescription = "Remove photo",
                                tint = Color.White,
                                modifier = Modifier.size(14.dp),
                            )
                        }
                    }
                }
                if (picked.size < maxPhotos) {
                    item("add") {
                        Box(
                            modifier = Modifier
                                .size(96.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(BrandGreen50)
                                .border(1.dp, BrandGreen, RoundedCornerShape(10.dp))
                                .padding(8.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            IconButton(
                                onClick = {
                                    launcher.launch(
                                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                    )
                                },
                                enabled = !submitting,
                            ) {
                                Icon(
                                    Icons.Filled.AddPhotoAlternate,
                                    contentDescription = "Add photos",
                                    tint = BrandGreen,
                                    modifier = Modifier.size(28.dp),
                                )
                            }
                        }
                    }
                }
            }
            if (picked.isEmpty()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.PhotoLibrary,
                        contentDescription = null,
                        tint = Ink500,
                        modifier = Modifier.size(14.dp),
                    )
                    Text("No photos yet — tap + to add", fontSize = 12.sp, color = Ink500)
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                OutlinedButton(
                    onClick = onDismiss,
                    enabled = !submitting,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = {
                        // Read each URI to bytes here (off-thread is overkill;
                        // photo picker payloads are small and the stash also
                        // copies to disk inside enqueue()). The ViewModel then
                        // hands them to PhotoUploadStash + flips the status.
                        val resolver = context.contentResolver
                        val photos = picked.mapNotNull { uri ->
                            val mime = resolver.getType(uri) ?: "image/jpeg"
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
                    },
                    enabled = !submitting,
                    modifier = Modifier.weight(1.4f),
                ) {
                    if (submitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                        Spacer(Modifier.width(8.dp))
                        Text("Saving…")
                    } else {
                        Text(if (picked.isEmpty()) "Mark done without photos" else "Submit + mark done")
                    }
                }
            }
            Spacer(Modifier.height(Spacing.sm))
        }
    }
}

private val UriListSaver = androidx.compose.runtime.saveable.listSaver<List<Uri>, String>(
    save = { it.map(Uri::toString) },
    restore = { it.map(Uri::parse) },
)
