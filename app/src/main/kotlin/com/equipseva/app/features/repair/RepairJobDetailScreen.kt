package com.equipseva.app.features.repair

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Phone
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
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
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.components.UrgencyPill
import com.equipseva.app.designsystem.components.VerifiedBadge
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500

private val WarnGold = Color(0xFFF5A623)

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
    var checkinSheetOpen by rememberSaveable { mutableStateOf(false) }
    var cancelSheetOpen by rememberSaveable { mutableStateOf(false) }
    var rateSheetOpen by rememberSaveable { mutableStateOf(false) }

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
        containerColor = PaperDefault,
        topBar = {
            EsTopBar(
                title = state.job?.jobNumber ?: "Repair request",
                subtitle = state.job?.equipmentLabel,
                onBack = onBack,
                right = {
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
            if (job != null) {
                StickyBottomBar(
                    job = job,
                    ownBid = state.ownBid,
                    viewerRole = state.viewerRole,
                    updatingStatus = state.updatingStatus,
                    onPlaceBid = viewModel::openBidComposer,
                    onCheckIn = { checkinSheetOpen = true },
                    onMarkDone = viewModel::openProofSheet,
                    onRate = { rateSheetOpen = true },
                    onCancel = { cancelSheetOpen = true },
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
                    acceptingBidId = state.acceptingBidId,
                    openingChat = state.openingChat,
                    afterPhotoSignedUrls = state.afterPhotoSignedUrls,
                    onMessageEngineer = viewModel::openChatWithEngineer,
                    onMessageHospital = viewModel::openChatWithHospital,
                    onAcceptBid = viewModel::acceptBid,
                    onWithdraw = { withdrawConfirmOpen = true },
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
            onConfirm = {
                checkinSheetOpen = false
                viewModel.checkIn()
            },
        )
    }

    if (cancelSheetOpen) {
        CancelSheet(
            updating = state.updatingStatus,
            onDismiss = { if (!state.updatingStatus) cancelSheetOpen = false },
            onConfirm = {
                cancelSheetOpen = false
                viewModel.cancelJob()
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
    acceptingBidId: String?,
    openingChat: Boolean,
    afterPhotoSignedUrls: List<String>,
    onMessageEngineer: () -> Unit,
    onMessageHospital: () -> Unit,
    onAcceptBid: (String) -> Unit,
    onWithdraw: () -> Unit,
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

        // Status stepper — 5 step linear timeline.
        StatusStepperRow(currentStatus = job.status)

        EsSection(title = "Equipment") {
            EquipmentCard(job = job)
        }

        EsSection(title = "Issue") {
            IssueCard(job = job)
        }

        // Assigned engineer (only if engineer is assigned + viewer is hospital).
        if (job.engineerId != null && isHospital) {
            EsSection(title = "Assigned engineer") {
                AssignedEngineerCard(
                    name = engineerNames[job.engineerId] ?: "Engineer",
                    openingChat = openingChat,
                    onMessage = onMessageEngineer,
                )
            }
        }

        // Bids — hospital + status==requested + bids.size>0.
        if (isHospital && job.status == RepairJobStatus.Requested && bids.isNotEmpty()) {
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

        Spacer(Modifier.height(20.dp))
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
private val StepLabels = listOf("Requested", "Assigned", "En route", "In progress", "Completed")
private val StepStatuses = listOf(
    RepairJobStatus.Requested,
    RepairJobStatus.Assigned,
    RepairJobStatus.EnRoute,
    RepairJobStatus.InProgress,
    RepairJobStatus.Completed,
)

@Composable
private fun StatusStepperRow(currentStatus: RepairJobStatus) {
    val currentIdx = StepStatuses.indexOf(currentStatus).let { if (it < 0) -1 else it }
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
                val done = currentIdx in 0 until i
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
    val schedule = listOfNotNull(
        job.scheduledDate?.takeIf { it.isNotBlank() },
        job.scheduledTimeSlot?.takeIf { it.isNotBlank() },
    ).joinToString(" ").ifBlank { "—" }
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        EqRow("Brand", job.equipmentBrand?.takeIf { it.isNotBlank() } ?: "—")
        Spacer(Modifier.height(8.dp))
        EqRow("Model", job.equipmentModel?.takeIf { it.isNotBlank() } ?: "—")
        Spacer(Modifier.height(8.dp))
        EqRow("Category", job.equipmentCategory.displayName)
        Spacer(Modifier.height(8.dp))
        EqRow("Schedule", schedule)
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
private fun IssueCard(job: RepairJob) {
    val photoCount = job.issuePhotos.size
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
        if (photoCount > 0) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp)
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                repeat(photoCount.coerceAtMost(4)) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Paper2),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.PhotoCamera,
                            contentDescription = null,
                            tint = SevaInk400,
                            modifier = Modifier.size(20.dp),
                        )
                    }
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
            EsBtn(
                text = "Call",
                onClick = onMessage,
                kind = EsBtnKind.Secondary,
                disabled = true,
                leading = {
                    Icon(
                        imageVector = Icons.Outlined.Phone,
                        contentDescription = null,
                        tint = SevaGreen700,
                        modifier = Modifier.size(16.dp),
                    )
                },
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
                    text = formatRupees(bid.amountRupees),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaGreen700,
                )
                bid.createdAtInstant?.let { placed ->
                    Text(
                        text = "${relativeLabel(placed)} ago",
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
        val etaText = bid.etaHours?.let { "ETA: ${it}h" } ?: "ETA: —"
        Text(
            text = etaText,
            fontSize = 12.sp,
            color = SevaInk600,
            lineHeight = 17.sp,
        )
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
            text = "Your bid",
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Text(
            text = buildString {
                append(formatRupees(ownBid.amountRupees))
                ownBid.etaHours?.let { append(" · ETA ${it}h") }
            },
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = SevaGreen900,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = "Status: ${ownBid.status.displayName}",
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
    val canShowAddress = !job.siteLocation.isNullOrBlank() &&
        (isHospital || (isEngineer && job.isAssignedToEngineer))

    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
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
                    text = "Map preview",
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
                            Uri.parse("geo:${job.siteLatitude},${job.siteLongitude}?q=${job.siteLatitude},${job.siteLongitude}($label)")
                        } else {
                            Uri.parse("geo:0,0?q=$encoded")
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
                                Uri.parse(fallbackUrl),
                            )
                            try { context.startActivity(fallback) } catch (_: Throwable) {}
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
                    "Full address shows up after the hospital accepts your bid."
                else
                    "Address will be shared once the bid is accepted.",
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
            text = "Photos uploaded by the engineer.",
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
    onPlaceBid: () -> Unit,
    onCheckIn: () -> Unit,
    onMarkDone: () -> Unit,
    onRate: () -> Unit,
    onCancel: () -> Unit,
) {
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val rated = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating != null
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating != null
        RepairJobDetailViewModel.ViewerRole.Other -> true
    }
    val canCancel = (isHospital || isEngineer) &&
        job.status in setOf(RepairJobStatus.Requested, RepairJobStatus.Assigned)

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
        else -> null
    }

    if (primaryKind == null && !canCancel) return

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
                text = if (updatingStatus) "Working…" else "Check in on-site",
                onClick = onCheckIn,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = updatingStatus,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.MarkDone -> EsBtn(
                text = "Mark done",
                onClick = onMarkDone,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.Rate -> EsBtn(
                text = "Rate engineer",
                onClick = onRate,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.RatedDone -> EsBtn(
                text = "Rated · Thanks!",
                onClick = {},
                kind = EsBtnKind.Secondary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = true,
                modifier = Modifier.weight(1f),
            )
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = if (existingBid != null) "Update your bid" else "Place your bid",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Price field
            Column {
                Text(
                    text = "Your price (₹)",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk700,
                    modifier = Modifier.padding(bottom = 6.dp),
                )
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
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
                        text = "Enter a valid amount",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(start = 4.dp, top = 4.dp),
                    )
                }
            }
            // ETA field
            EsField(
                value = eta,
                onChange = { eta = it.filter(Char::isDigit) },
                label = "When can you arrive? (hours)",
                placeholder = "e.g. 4",
                type = EsFieldType.Number,
                error = if (etaError) "Enter hours as a positive whole number" else null,
                modifier = Modifier.onFocusChanged { focusState ->
                    if (!focusState.isFocused && etaFocused) etaTouched = true
                    etaFocused = focusState.isFocused
                },
            )
            // Note field
            EsField(
                value = note,
                onChange = { note = it },
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
                    text = "Your bid is locked once submitted. Hospital sees your verified profile.",
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
    onConfirm: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(SevaGreen50),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.LocationOn,
                    contentDescription = null,
                    tint = SevaGreen700,
                    modifier = Modifier.size(32.dp),
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = "Confirm you've reached the site?",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
                textAlign = TextAlign.Center,
            )
            Text(
                text = "This notifies the hospital and changes status to \"In progress\".",
                fontSize = 12.sp,
                color = SevaInk500,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            EsBtn(
                text = if (updating) "Confirming…" else "Yes, I'm here",
                onClick = onConfirm,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = updating,
            )
            EsBtn(
                text = "Not yet",
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
    var picked by rememberSaveable(stateSaver = UriListSaver) { mutableStateOf(emptyList<Uri>()) }
    var note by rememberSaveable { mutableStateOf("") }
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
                text = "Mark job done",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                text = "After-photos (required)",
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
                            IconButton(
                                onClick = { picked = picked - uri },
                                enabled = !submitting,
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(22.dp)
                                    .padding(2.dp)
                                    .background(Color.Black.copy(alpha = 0.55f), CircleShape),
                            ) {
                                Icon(
                                    Icons.Filled.Close,
                                    contentDescription = "Remove",
                                    tint = Color.White,
                                    modifier = Modifier.size(12.dp),
                                )
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
            EsField(
                value = note,
                onChange = { note = it },
                label = "Work summary",
                placeholder = "Replaced SpO2 module. Calibration verified.",
                type = EsFieldType.Multiline,
            )
            EsBtn(
                text = if (submitting) "Saving…" else "Mark done",
                onClick = {
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
    var rating by rememberSaveable(existing) { mutableStateOf(existing ?: 0) }
    var note by rememberSaveable { mutableStateOf("") }
    val labels = listOf("Poor", "Fair", "Good", "Great", "Excellent")

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "Rate engineer",
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
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .clickable(enabled = existing == null && !submitting) {
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
                text = if (rating == 0) "Tap to rate" else labels[rating - 1],
                fontSize = 13.sp,
                color = SevaInk500,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            EsField(
                value = note,
                onChange = { note = it },
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
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var reason by rememberSaveable { mutableStateOf("") }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "Cancel job?",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                text = "This cannot be undone. The other party will be notified.",
                fontSize = 13.sp,
                color = SevaInk600,
            )
            EsField(
                value = reason,
                onChange = { reason = it },
                label = "Reason",
                placeholder = "Why are you cancelling?",
                type = EsFieldType.Multiline,
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
                    onClick = onConfirm,
                    kind = EsBtnKind.Danger,
                    full = true,
                    disabled = updating,
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
            text = "${parts.joinToString(" + ")} queued — will sync when back online",
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
            "This repair job is no longer available.",
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

private fun initialsOf(name: String): String {
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
