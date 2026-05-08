package com.equipseva.app.features.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.width
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.R
import com.equipseva.app.core.data.cashsurvey.CashSurveyRepository
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.InlineStars
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.features.auth.UserRole
import java.time.Duration
import java.time.Instant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeHubScreen(
    onOpenBookRepair: () -> Unit,
    onOpenEngineerJobs: () -> Unit,
    onOpenFounder: () -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    onOpenKyc: () -> Unit = {},
    onOpenMyBookings: () -> Unit = {},
    onOpenMessages: () -> Unit = {},
    onOpenActiveWork: () -> Unit = {},
    onOpenEarnings: () -> Unit = {},
    onOpenEngineerProfile: (engineerId: String) -> Unit = {},
    onOpenAmcContracts: () -> Unit = {},
    viewModel: HomeHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val role = state.role
    val kyc = state.kycStatus

    androidx.lifecycle.compose.LifecycleResumeEffect(viewModel) {
        viewModel.refreshNow()
        onPauseOrDispose { }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            HomeTopBar(onNotifications = onOpenNotifications, hasUnread = state.recent.any { it.isUnread })

            // Greeting card
            Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                GreetingCard(
                    role = role,
                    displayName = state.displayName,
                    openCount = state.openCount,
                    activeCount = state.activeCount,
                    pendingBidsCount = state.pendingBidsCount,
                    nearbyEngineersCount = state.nearbyEngineersCount,
                )
            }

            // KYC banner — engineer who isn't verified yet
            if (role == UserRole.ENGINEER && kyc != VerificationStatus.Verified) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    KycBanner(status = kyc, onClick = onOpenKyc)
                }
            }

            Spacer(Modifier.height(8.dp))

            // PR-D15: hospital loyalty progress pill — surfaces the
            // commission tier (PR-D2) so hospitals can see what they
            // unlock at 10 / 50 completed jobs/yr.
            val tier = state.commissionTier
            if (role == UserRole.HOSPITAL && tier != null) {
                CommissionTierPill(tier = tier)
                Spacer(Modifier.height(8.dp))
            }

            // PR-D34: aggregated AMC SLA breach credits this hospital
            // received in the trailing 30 days. Only rendered when
            // total > 0 (handled in the VM). Tap routes to the AMC
            // contracts list where the SLA tab lives.
            val slaCredits = state.recentSlaCredits
            if (role == UserRole.HOSPITAL && slaCredits != null) {
                SlaCreditsCard(summary = slaCredits, onClick = onOpenAmcContracts)
                Spacer(Modifier.height(8.dp))
            }

            // PR-B: hospital home carousel of top-N recommended engineers.
            // Hidden gracefully when no GPS / no rows so we never render
            // an empty band. The static "Book a repair engineer" tile
            // below remains the always-on fallback path.
            if (role == UserRole.HOSPITAL && state.recommended.isNotEmpty()) {
                RecommendedEngineersCarousel(
                    rows = state.recommended,
                    onPick = onOpenEngineerProfile,
                    onSeeAll = onOpenBookRepair,
                )
                Spacer(Modifier.height(4.dp))
            }

            // Tiles — role-aware per design (`screens-home.jsx:103-140`).
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (role == UserRole.HOSPITAL) {
                    HomeTile(
                        icon = Icons.Filled.Bolt,
                        title = "Book a repair engineer",
                        desc = "Browse verified biomedical engineers near you",
                        onClick = onOpenBookRepair,
                    )
                    HomeTile(
                        icon = Icons.Outlined.WorkOutline,
                        title = "My bookings",
                        desc = "Track open and active repair jobs",
                        onClick = onOpenMyBookings,
                    )
                    HomeTile(
                        icon = Icons.AutoMirrored.Outlined.Chat,
                        title = "Messages",
                        desc = "Chat with engineers",
                        onClick = onOpenMessages,
                    )
                } else {
                    val engVerified = kyc == VerificationStatus.Verified
                    HomeTile(
                        icon = Icons.Filled.Build,
                        title = "Today's jobs",
                        desc = if (engVerified) "New requests near you" else "Browse open repair jobs",
                        onClick = onOpenEngineerJobs,
                    )
                    HomeTile(
                        icon = Icons.Outlined.WorkOutline,
                        title = "Active work",
                        desc = "Jobs in progress",
                        onClick = onOpenActiveWork,
                    )
                    HomeTile(
                        icon = Icons.Filled.CurrencyRupee,
                        title = "Earnings",
                        desc = "This month, payouts, tax docs",
                        onClick = onOpenEarnings,
                    )
                }
                if (state.isFounder) {
                    HomeTile(
                        icon = Icons.Filled.Shield,
                        title = "Admin Dashboard",
                        desc = "Founder tools — KYC queue, reports, payments",
                        onClick = onOpenFounder,
                        accent = TileAccent.Admin,
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Recent activity
            if (state.recent.isNotEmpty()) {
                EsSection(
                    title = "Recent activity",
                    action = "See all",
                    onAction = onOpenNotifications,
                ) {
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                    ) {
                        state.recent.forEachIndexed { i, n ->
                            ActivityRow(
                                kind = n.kind,
                                title = n.title.ifBlank { n.body },
                                relativeTime = relativeTime(n.sentAt),
                                unread = n.isUnread,
                                isLast = i == state.recent.lastIndex,
                                onClick = onOpenNotifications,
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }

        // PR-D1: post-completion cash-payment survey. Bottom-sheet pops
        // when refresh() finds an un-surveyed completed job 24h..7d old.
        // Hospital answers once → submit_cash_survey records it; "Skip"
        // just dismisses for this app open and the prompt re-fires next
        // foreground (idempotent on the server).
        val pendingSurvey = state.pendingCashSurvey
        if (pendingSurvey != null) {
            val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ModalBottomSheet(
                onDismissRequest = { viewModel.dismissCashSurvey() },
                sheetState = sheetState,
            ) {
                CashSurveySheetBody(
                    survey = pendingSurvey,
                    onAnswer = { response ->
                        viewModel.submitCashSurvey(response)
                    },
                )
            }
        }

        // PR-D43: spot-audit invitation. 1-in-20 sample of completed
        // jobs, server-rate-limited to one open per hospital. Skip just
        // dismisses for this app open; sheet re-renders next foreground
        // until expires_at lapses (7 days).
        val pendingAudit = state.pendingSpotAudit
        if (pendingAudit != null) {
            val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ModalBottomSheet(
                onDismissRequest = { viewModel.dismissSpotAudit() },
                sheetState = sheetState,
            ) {
                SpotAuditSheetBody(
                    invitation = pendingAudit,
                    submitting = state.submittingSpotAudit,
                    onSubmit = { rating, feedback ->
                        viewModel.submitSpotAudit(rating, feedback)
                    },
                )
            }
        }
    }
}

@Composable
private fun SpotAuditSheetBody(
    invitation: com.equipseva.app.core.data.spotaudit.SpotAuditRepository.PendingInvitation,
    submitting: Boolean,
    onSubmit: (rating: Int, feedback: String?) -> Unit,
) {
    var rating by rememberSaveable { androidx.compose.runtime.mutableStateOf(0) }
    var feedback by rememberSaveable { androidx.compose.runtime.mutableStateOf("") }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "Quick quality check",
            style = EsType.H2,
            color = SevaInk900,
        )
        Text(
            text = "Job ${invitation.jobNumber ?: "RPR-${invitation.repairJobId.take(6)}"} with ${invitation.engineerName ?: "the engineer"} just wrapped. Rate the work.",
            style = EsType.Body,
            color = SevaInk700,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            (1..5).forEach { star ->
                val isOn = rating >= star
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(
                            if (isOn) com.equipseva.app.designsystem.theme.SevaWarning500 else androidx.compose.ui.graphics.Color.White,
                        )
                        .border(
                            1.dp,
                            com.equipseva.app.designsystem.theme.SevaWarning500,
                            androidx.compose.foundation.shape.CircleShape,
                        )
                        .clickable { rating = star }
                        .padding(8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = star.toString(),
                        color = if (isOn) androidx.compose.ui.graphics.Color.White
                        else com.equipseva.app.designsystem.theme.SevaWarning500,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    )
                }
            }
        }
        androidx.compose.material3.OutlinedTextField(
            value = feedback,
            onValueChange = { if (it.length <= 500) feedback = it },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("Optional comments (e.g. parts replaced as expected, slow response, etc.)") },
            minLines = 2,
            maxLines = 5,
        )
        SurveyAnswerButton(
            label = if (submitting) "Submitting…" else "Submit",
            primary = true,
            onClick = {
                if (rating in 1..5 && !submitting) {
                    onSubmit(rating, feedback.trim().takeIf { it.isNotBlank() })
                }
            },
        )
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun CashSurveySheetBody(
    survey: CashSurveyRepository.PendingSurvey,
    onAnswer: (CashSurveyRepository.Response) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "Quick check-in",
            style = EsType.H2,
            color = SevaInk900,
        )
        Text(
            text = "Job ${survey.jobNumber} with ${survey.engineerName} just wrapped. Did the engineer ask for any payment outside the app?",
            style = EsType.Body,
            color = SevaInk700,
        )
        Text(
            text = "Your answer is private and only visible to our team.",
            style = EsType.Caption,
            color = SevaInk500,
        )
        Spacer(Modifier.height(4.dp))
        SurveyAnswerButton(
            label = "Yes — engineer asked for cash",
            primary = false,
            onClick = { onAnswer(CashSurveyRepository.Response.AskedCash) },
        )
        SurveyAnswerButton(
            label = "No — payment was through the app",
            primary = true,
            onClick = { onAnswer(CashSurveyRepository.Response.NoCash) },
        )
        SurveyAnswerButton(
            label = "Prefer not to say",
            primary = false,
            onClick = { onAnswer(CashSurveyRepository.Response.Declined) },
        )
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun SurveyAnswerButton(
    label: String,
    primary: Boolean,
    onClick: () -> Unit,
) {
    val bg = if (primary) SevaGreen700 else PaperDefault
    val fg = if (primary) Color.White else SevaInk900
    val border = if (primary) SevaGreen700 else BorderDefault
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp, horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = label, style = EsType.Body, color = fg, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SlaCreditsCard(
    summary: com.equipseva.app.core.data.amc.AmcRepository.HospitalSlaCreditSummary,
    onClick: () -> Unit,
) {
    val rupeesLabel = "%,.0f".format(summary.totalCreditRupees)
    val sub = if (summary.breachCount == 1) {
        "1 SLA breach in the last 30 days. Tap to review."
    } else {
        "${summary.breachCount} SLA breaches in the last 30 days. Tap to review."
    }
    Row(
        modifier = androidx.compose.ui.Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(com.equipseva.app.designsystem.theme.SevaGreen50)
            .border(1.dp, com.equipseva.app.designsystem.theme.SevaGreen700, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = androidx.compose.ui.Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(Color.White)
                .border(1.dp, com.equipseva.app.designsystem.theme.SevaGreen700, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "₹",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = com.equipseva.app.designsystem.theme.SevaGreen700,
            )
        }
        Column(modifier = androidx.compose.ui.Modifier.weight(1f)) {
            Text(
                text = "₹$rupeesLabel credited for SLA misses",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(text = sub, fontSize = 11.sp, color = SevaInk500)
        }
    }
}

@Composable
private fun CommissionTierPill(
    tier: com.equipseva.app.core.data.commissiontier.CommissionTierRepository.TierInfo,
) {
    val sub = if (tier.isTopTier) {
        "Top tier — ${tier.currentRateLabel} commission on every job."
    } else {
        "${tier.completed12m} jobs in last 12 months · ${tier.jobsToNextTier} more to ${tier.nextRateLabel} commission."
    }
    Row(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaInfo50)
            .border(1.dp, SevaInfo500, RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(Color.White)
                .border(1.dp, SevaInfo500, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = tier.currentRateLabel,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInfo500,
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Loyalty commission tier",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(text = sub, fontSize = 11.sp, color = SevaInk500)
        }
    }
}

@Composable
private fun HomeTopBar(onNotifications: () -> Unit, hasUnread: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(PaperDefault)
            .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(R.drawable.ic_logo_mark),
            contentDescription = "EquipSeva",
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp)),
        )
        Spacer(Modifier.size(10.dp))
        Text(
            text = "EquipSeva",
            style = EsType.H5,
            color = SevaInk900,
            modifier = Modifier.weight(1f),
        )
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .clickable(onClick = onNotifications),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Notifications,
                contentDescription = "Notifications",
                tint = SevaInk700,
                modifier = Modifier.size(20.dp),
            )
            if (hasUnread) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500)
                        .border(2.dp, Color.White, CircleShape)
                        .align(Alignment.TopEnd),
                )
            }
        }
    }
}

@Composable
private fun GreetingCard(
    role: UserRole?,
    displayName: String?,
    openCount: Int?,
    activeCount: Int?,
    pendingBidsCount: Int?,
    nearbyEngineersCount: Int?,
) {
    val greeting = remember { greetingForNow() }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.linearGradient(listOf(SevaGreen700, SevaGreen900)))
            .padding(18.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(140.dp)
                .clip(CircleShape)
                .background(SevaGlowRaw.copy(alpha = 0.08f)),
        )
        Column {
            Text(
                text = greeting,
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.75f),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (role == UserRole.ENGINEER) "Ready for work today?" else "What needs fixing today?",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                if (role == UserRole.ENGINEER) {
                    // "Nearby" is location-derived and not yet wired into this
                    // hero — left as "—" until a radius RPC stream lands.
                    Stat("Nearby", "—")
                    Stat("Pending bids", pendingBidsCount?.toString() ?: "—")
                    Stat("Active", activeCount?.toString() ?: "—")
                } else {
                    Stat("Open", openCount?.toString() ?: "—")
                    Stat("Active", activeCount?.toString() ?: "—")
                    Stat("Engineers", nearbyEngineersCount?.toString() ?: "—")
                }
            }
            if (!displayName.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(label, fontSize = 12.sp, color = Color.White.copy(alpha = 0.65f))
        Spacer(Modifier.height(2.dp))
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
    }
}

@Composable
private fun KycBanner(status: VerificationStatus?, onClick: () -> Unit) {
    val pending = status == VerificationStatus.Pending
    val bg = if (pending) SevaInfo50 else SevaWarning50
    val tint = if (pending) SevaInfo500 else SevaWarning500
    val title = when (status) {
        VerificationStatus.Pending -> "KYC under review"
        VerificationStatus.Rejected -> "KYC needs another try"
        else -> "Become a verified repairman"
    }
    val sub = when (status) {
        VerificationStatus.Pending -> "Usually 24h. We'll notify you."
        VerificationStatus.Rejected -> "Re-submit the missing docs to enter the queue."
        else -> "Submit KYC to start bidding on jobs."
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.Shield, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = SevaInk900)
            Spacer(Modifier.height(2.dp))
            Text(sub, fontSize = 11.sp, color = SevaInk600)
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(16.dp),
        )
    }
}

private enum class TileAccent { Default, Admin }

@Composable
private fun HomeTile(
    icon: ImageVector,
    title: String,
    desc: String,
    onClick: () -> Unit,
    badge: String? = null,
    accent: TileAccent = TileAccent.Default,
) {
    val tileBg = when (accent) {
        TileAccent.Default -> SevaGreen50
        TileAccent.Admin -> SevaWarning50
    }
    val tileFg = when (accent) {
        TileAccent.Default -> SevaGreen700
        TileAccent.Admin -> SevaWarning500
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(tileBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = tileFg, modifier = Modifier.size(24.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
                if (badge != null) Pill(text = badge, kind = PillKind.Warn)
            }
            Spacer(Modifier.height(4.dp))
            Text(desc, fontSize = 12.sp, color = SevaInk500, lineHeight = 16.sp)
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
private fun ActivityRow(
    kind: String?,
    title: String,
    relativeTime: String,
    unread: Boolean,
    isLast: Boolean,
    onClick: () -> Unit,
) {
    val icon = when (kind) {
        "bid", "job_bid" -> Icons.Filled.CurrencyRupee
        "msg", "chat", "message" -> Icons.Filled.ChatBubbleOutline
        "kyc", "verification" -> Icons.Filled.Shield
        else -> Icons.Filled.Bolt
    }
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(SevaGreen50),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = SevaGreen700, modifier = Modifier.size(16.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, color = SevaInk900, lineHeight = 18.sp)
                Spacer(Modifier.height(3.dp))
                Text(relativeTime, fontSize = 11.sp, color = SevaInk400)
            }
            if (unread) {
                Box(
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500),
                )
            }
        }
        if (!isLast) {
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
        }
    }
}

@Composable
private fun RecommendedEngineersCarousel(
    rows: List<EngineerDirectoryRepository.RecommendedRow>,
    onPick: (engineerId: String) -> Unit,
    onSeeAll: () -> Unit,
) {
    EsSection(
        title = "Verified engineers near you",
        action = "See all",
        onAction = onSeeAll,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            rows.forEach { row ->
                RecommendedEngineerCard(row = row, onPick = { onPick(row.engineerId) })
            }
        }
    }
}

@Composable
private fun RecommendedEngineerCard(
    row: EngineerDirectoryRepository.RecommendedRow,
    onPick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(220.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(14.dp))
            .clickable(onClick = onPick)
            .padding(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(listOf(SevaGreen700, SevaGreen900)),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (!row.avatarUrl.isNullOrBlank()) {
                    AsyncImage(
                        model = row.avatarUrl,
                        contentDescription = null,
                        modifier = Modifier.size(44.dp).clip(CircleShape),
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                    )
                } else {
                    Text(
                        text = row.fullName.take(2).uppercase(),
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.fullName,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                    maxLines = 1,
                )
                val parts = listOfNotNull(
                    row.city,
                    row.distanceKm?.let { "${"%.1f".format(it)} km" },
                )
                if (parts.isNotEmpty()) {
                    Text(
                        text = parts.joinToString(" · "),
                        fontSize = 11.sp,
                        color = SevaInk500,
                        maxLines = 1,
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            InlineStars(rating = row.ratingAvg, count = row.totalJobs, small = true)
            Text(
                text = "Book",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaGreen700,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(SevaGreen50)
                    .clickable(onClick = onPick)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            )
        }
    }
}

private fun greetingForNow(): String {
    val h = java.time.LocalTime.now().hour
    return when {
        h < 12 -> "Good morning"
        h < 17 -> "Good afternoon"
        else -> "Good evening"
    }
}

private fun relativeTime(at: Instant?): String {
    if (at == null) return ""
    val d = Duration.between(at, Instant.now())
    val mins = d.toMinutes()
    return when {
        mins < 1 -> "just now"
        mins < 60 -> "${mins}m ago"
        mins < 60 * 24 -> "${mins / 60}h ago"
        else -> "${mins / (60 * 24)}d ago"
    }
}

