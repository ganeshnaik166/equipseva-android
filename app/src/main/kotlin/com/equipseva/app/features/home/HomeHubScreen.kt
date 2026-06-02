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
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.initialsOf
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
    onOpenAddPhone: () -> Unit = {},
    onOpenMyBookings: () -> Unit = {},
    onOpenMessages: () -> Unit = {},
    onOpenActiveWork: () -> Unit = {},
    onOpenEarnings: () -> Unit = {},
    onOpenEngineerProfile: (engineerId: String) -> Unit = {},
    onOpenEngineerSelfProfile: () -> Unit = {},
    onOpenAmcContracts: () -> Unit = {},
    onShowMessage: (String) -> Unit = {},
    viewModel: HomeHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val role = state.role
    val kyc = state.kycStatus

    // Skip the first ON_RESUME so the VM init refresh isn't doubled —
    // the hub is the cold-start landing screen for hospital users.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.refreshNow() }

    // Surface one-shot VM errors (cash survey + spot-audit submit
    // failures) via the host snackbar. Without this, transient network
    // failures clear the dialog with no signal to the user.
    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
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

            // Directory-visibility banner — engineer is KYC-verified but
            // hospitals can't see them because the hospital-side filter
            // (`isBookable` in EngineerDirectoryViewModel) drops rows
            // without an hourly rate or specializations. Without this
            // banner the engineer has no signal: they completed KYC,
            // their profile says "Verified", yet they receive zero
            // bookings forever. Only render when KYC has cleared so
            // the engineer sees ONE nag at a time, not two stacked.
            if (role == UserRole.ENGINEER &&
                kyc == VerificationStatus.Verified &&
                state.directoryGate.isHidden
            ) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    DirectoryVisibilityBanner(
                        gate = state.directoryGate,
                        onClick = onOpenEngineerSelfProfile,
                    )
                }
            }

            // Phone-missing banner — hospitals without a phone number
            // can't be called by an engineer during a job. The
            // "Required" badge in Profile is invisible to a user who
            // never visits Profile, so surface it on Home too. Only
            // for hospitals; engineers see the KYC banner instead
            // which already covers phone-as-part-of-KYC.
            if (role == UserRole.HOSPITAL && state.phoneMissing) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    PhoneMissingBanner(onClick = onOpenAddPhone)
                }
            }

            // Razorpay process-death marker: any AMC payment whose
            // checkout activity didn't return cleanly AND whose
            // server-side status is still 'pending' surfaces here so
            // the hospital can reach out if their bank shows a charge
            // but the contract pool hasn't credited. The reconciler in
            // Application.onCreate already removes terminal entries.
            if (role == UserRole.HOSPITAL && state.pendingAmcPaymentsCount > 0) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    PendingAmcPaymentBanner(count = state.pendingAmcPaymentsCount)
                }
            }

            Spacer(Modifier.height(8.dp))

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
                        // "Today's jobs" implied a same-day filter that never
                        // existed — the destination is the engineer hub
                        // which surfaces every open job in the configured
                        // radius regardless of when it was posted.
                        title = "Find work",
                        desc = if (engVerified) "New requests near you" else "Browse open repair jobs",
                        onClick = onOpenEngineerJobs,
                    )
                    HomeTile(
                        icon = Icons.Outlined.WorkOutline,
                        title = "Active work",
                        desc = "Jobs in progress",
                        onClick = onOpenActiveWork,
                    )
                    // Engineers can chat with hospitals on bid/assigned jobs;
                    // hospitals had a Messages home tile but engineers had to
                    // dig into a specific job → chat to see threads. Add the
                    // same shortcut here.
                    HomeTile(
                        icon = Icons.AutoMirrored.Outlined.Chat,
                        title = "Messages",
                        desc = "Chat with hospitals",
                        onClick = onOpenMessages,
                    )
                    HomeTile(
                        icon = Icons.Filled.CurrencyRupee,
                        title = "Earnings",
                        // Earnings screen shows All-time totals + escrow
                        // status + recent payouts. No "this month" rollup
                        // and no tax docs surface in v2.1, so the previous
                        // copy promised more than the screen delivers.
                        desc = "Payouts, escrow status, recent jobs",
                        onClick = onOpenEarnings,
                    )
                }
                if (state.isFounder) {
                    HomeTile(
                        icon = Icons.Filled.Shield,
                        title = "Admin dashboard",
                        desc = "Founder tools — KYC queue, reports, payments",
                        onClick = onOpenFounder,
                        accent = TileAccent.Admin,
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Recent activity — round 341: show a placeholder card when
            // empty rather than collapsing the section. First-time users
            // landed on Home and saw nothing below the role tiles, which
            // read as "the app is broken / nothing here". The placeholder
            // gives them an anchor + clarifies what'll fill this slot.
            EsSection(
                title = "Recent activity",
                action = if (state.recent.isNotEmpty()) "See all" else null,
                onAction = if (state.recent.isNotEmpty()) onOpenNotifications else null,
            ) {
                Column(
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White)
                        .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                ) {
                    if (state.recent.isEmpty()) {
                        val empty = homeRecentEmptyCopy(role)
                        Text(
                            text = empty,
                            color = SevaInk500,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 18.dp),
                        )
                    } else {
                        // Round 459 — precompute the relative-time label
                        // and the isLast flag once per state.recent
                        // identity. Previously each parent recomposition
                        // (SLA-credit update, pending survey tick, role
                        // refresh, etc.) re-parsed every notification's
                        // ISO timestamp via relativeTime(). Cached now
                        // so unrelated state changes don't churn the row
                        // params.
                        val labeledRows = remember(state.recent) {
                            val last = state.recent.lastIndex
                            state.recent.mapIndexed { i, n ->
                                Triple(n, relativeTime(n.sentAt), i == last)
                            }
                        }
                        labeledRows.forEach { (n, timeLabel, isLast) ->
                            ActivityRow(
                                kind = n.kind,
                                title = n.title.ifBlank { n.body },
                                relativeTime = timeLabel,
                                unread = n.isUnread,
                                isLast = isLast,
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
    var rating by rememberSaveable { mutableIntStateOf(0) }
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
            text = spotAuditQuestionBody(
                jobNumber = invitation.jobNumber,
                repairJobId = invitation.repairJobId,
                engineerName = invitation.engineerName,
            ),
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
                        .clickable(
                            onClickLabel = "Rate $star out of 5",
                            role = androidx.compose.ui.semantics.Role.Button,
                        ) { rating = star }
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
                if (canSubmitSpotAudit(rating, submitting)) {
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
            text = cashSurveyQuestionBody(survey.jobNumber, survey.engineerName),
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
    val title = slaCreditsCardTitle(summary.totalCreditRupees)
    val sub = slaCreditsCardSubtitle(summary.breachCount)
    Row(
        modifier = androidx.compose.ui.Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(com.equipseva.app.designsystem.theme.SevaGreen50)
            .border(1.dp, com.equipseva.app.designsystem.theme.SevaGreen700, RoundedCornerShape(12.dp))
            .clickable(
                onClickLabel = "View SLA breaches",
                role = androidx.compose.ui.semantics.Role.Button,
                onClick = onClick,
            )
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
                // formatRupees already includes the ₹ prefix.
                text = title,
                fontSize = 13.sp,
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
                .clickable(
                    onClickLabel = "Open notifications",
                    role = androidx.compose.ui.semantics.Role.Button,
                    onClick = onNotifications,
                ),
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
                text = greetingHeroQuestion(role),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                if (role == UserRole.ENGINEER) {
                    // "Nearby" used to render here as a permanent "—" until
                    // the radius RPC stream lands. Dropped — a stat that
                    // never has a value just sits on the hero looking like
                    // a load failure. Two real stats is honest; a third
                    // joins when there's a real number to put in it.
                    Stat("Pending bids", pendingBidsCount?.toString() ?: "—")
                    // "Active" was overloaded with the StatusStepper's
                    // "In progress" step on the job-detail screen — same
                    // job rendered as "Active" on Home but "In progress"
                    // on detail. Unify on "In progress" so the surface
                    // copy matches the state-machine label everywhere.
                    Stat("In progress", activeCount?.toString() ?: "—")
                } else {
                    Stat("Open", openCount?.toString() ?: "—")
                    Stat("In progress", activeCount?.toString() ?: "—")
                    Stat("Engineers", nearbyEngineersCount?.toString() ?: "—")
                }
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
    val copy = homeKycBannerCopy(status)
    val title = copy.title
    val sub = copy.subtitle
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .clickable(
                onClickLabel = "Open KYC",
                role = androidx.compose.ui.semantics.Role.Button,
                onClick = onClick,
            )
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

@Composable
private fun DirectoryVisibilityBanner(
    gate: HomeHubViewModel.DirectoryGate,
    onClick: () -> Unit,
) {
    val (title, sub) = directoryVisibilityCopy(gate) ?: return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaInfo50)
            .clickable(
                onClickLabel = "Complete your engineer profile",
                role = androidx.compose.ui.semantics.Role.Button,
                onClick = onClick,
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.Visibility,
            contentDescription = null,
            tint = SevaInfo500,
            modifier = Modifier.size(20.dp),
        )
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

/**
 * Copy for the directory-visibility banner. Returns null for any gate
 * state that shouldn't render a banner (Unknown / Visible) — keeps the
 * caller a one-liner.
 */
internal fun directoryVisibilityCopy(
    gate: HomeHubViewModel.DirectoryGate,
): Pair<String, String>? = when (gate) {
    HomeHubViewModel.DirectoryGate.MissingBoth ->
        "You're not visible to hospitals yet" to
            "Add your hourly rate and at least one specialization so hospitals can find and book you."
    HomeHubViewModel.DirectoryGate.MissingRate ->
        "Add your hourly rate to start getting bookings" to
            "Hospitals filter by rate — your profile is hidden from the directory until you set one."
    HomeHubViewModel.DirectoryGate.MissingSpecs ->
        "Pick at least one specialization" to
            "Hospitals search by equipment type — your profile won't appear until you select what you service."
    HomeHubViewModel.DirectoryGate.Unknown,
    HomeHubViewModel.DirectoryGate.Visible -> null
}

@Composable
private fun PhoneMissingBanner(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaWarning50)
            .clickable(
                onClickLabel = "Add your phone number",
                role = androidx.compose.ui.semantics.Role.Button,
                onClick = onClick,
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.Phone,
            contentDescription = null,
            tint = SevaWarning500,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Add your phone number",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                "Engineers call this number during a job. Without it they can't reach you.",
                fontSize = 11.sp,
                color = SevaInk600,
            )
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun PendingAmcPaymentBanner(count: Int) {
    val title = pendingAmcPaymentBannerTitle(count)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaWarning50)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.Phone,
            contentDescription = null,
            tint = SevaWarning500,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                "If your bank shows the charge but your AMC pool hasn't credited yet, " +
                    "contact support and we'll reconcile.",
                fontSize = 11.sp,
                color = SevaInk600,
            )
        }
    }
}

/**
 * Title copy for the pending AMC-payment banner. Singular vs plural
 * split — pin the explicit "1 payment" → unsigned "Payment may still
 * be in progress" so the count doesn't read as "1 payments".
 *
 * Count of 0 shouldn't reach the banner (caller gates), but pin a
 * sensible fallback to the plural shape so the helper is total.
 */
internal fun pendingAmcPaymentBannerTitle(count: Int): String =
    if (count == 1) "Payment may still be in progress"
    else "$count payments may still be in progress"

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
        // "Verified engineers near you" lied when GPS was off (the
        // recommended list still rendered from cached + rating-sorted
        // rows with no proximity guarantee). The neutral "Recommended
        // engineers" title is true regardless of location state.
        title = "Recommended engineers",
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
                        text = initialsOf(row.fullName),
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
                val cityDistance = recommendedEngineerCityDistanceLine(row.city, row.distanceKm)
                if (cityDistance != null) {
                    Text(
                        text = cityDistance,
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
            // Was "Book" — but the tap doesn't book anything, it opens
            // the engineer's public profile (same destination as tapping
            // the card itself). Tapping a "Book" pill and getting a
            // profile screen is a small lie. Renamed to match what
            // happens; the actual booking starts from the profile's
            // sticky "Post a repair job" CTA.
            Text(
                text = "View",
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

private fun greetingForNow(): String = greetingForHour(java.time.LocalTime.now().hour)

/**
 * Pure form of [greetingForNow]. The screen calls this with
 * `LocalTime.now().hour`; tests can pass an arbitrary hour to exercise
 * the three buckets without resetting the system clock.
 */
internal fun greetingForHour(hour: Int): String = when {
    hour < 12 -> "Good morning"
    hour < 17 -> "Good afternoon"
    else -> "Good evening"
}

/**
 * Role-aware hero question on the home greeting card.
 *
 *   - ENGINEER → "Ready for work today?" (an availability prompt;
 *     the engineer's mental model is "should I take a job today?")
 *   - HOSPITAL (and any non-engineer / null role) → "What needs
 *     fixing today?" (a service-need prompt; the hospital's mental
 *     model is "I have broken equipment").
 *
 * Pin the question marks — both lines end with '?'. A refactor that
 * dropped the '?' would soften the call-to-action and disrupt the
 * card's conversational tone.
 *
 * Pin the default-to-hospital branch — null role (cold-load before
 * the role resolves) falls to the hospital question, which is the
 * majority-case copy. A refactor that returned blank on null would
 * leave the hero card looking unfinished during the brief load window.
 */
internal fun greetingHeroQuestion(role: UserRole?): String =
    if (role == UserRole.ENGINEER) {
        "Ready for work today?"
    } else {
        "What needs fixing today?"
    }

/**
 * City + distance subline on the recommended-engineer carousel card.
 *
 * Composes the optional city + distance ("%.1f km") into "City · X.Y km"
 * via U+00B7 middle-dot. Returns null when BOTH inputs are absent so the
 * caller can omit the Text entirely (avoiding an empty subline that
 * would break the card's vertical rhythm).
 *
 * Critical pin:
 *   - Locale.ENGLISH formatter — Hindi-locale would render "3,2 km".
 *     Note: this helper uses ENGLISH, not US — same decimal point but
 *     ENGLISH is the broader fallback.
 *   - "%.1f km" with one decimal — pin so a drift to "%.0f km" loses
 *     sub-km precision (an engineer 0.4km away suddenly reads "0 km").
 *   - The bare "km" suffix (no space before, NOT " km" without
 *     decimal precision adjustment).
 *
 * Null-only inputs collapse to null (caller hides row); city-only or
 * distance-only renders that single field.
 */
internal fun recommendedEngineerCityDistanceLine(
    city: String?,
    distanceKm: Double?,
): String? {
    val parts = listOfNotNull(
        city,
        distanceKm?.let { "${"%.1f".format(java.util.Locale.ENGLISH, it)} km" },
    )
    return if (parts.isEmpty()) null else parts.joinToString(" · ")
}

private fun relativeTime(at: Instant?): String =
    if (at == null) "" else relativeTimeFromMinutes(Duration.between(at, Instant.now()).toMinutes())

/**
 * Pure form of [relativeTime]. Bucketed copy that the home dashboard
 * uses for "X ago" labels.
 */
internal fun relativeTimeFromMinutes(mins: Long): String = when {
    mins < 1 -> "just now"
    mins < 60 -> "${mins}m ago"
    mins < 60 * 24 -> "${mins / 60}h ago"
    else -> "${mins / (60 * 24)}d ago"
}

/**
 * Title + subtitle copy for the home-screen KYC banner. Three states:
 *
 *   * Pending — engineer has submitted, awaiting review.
 *   * Rejected — admin flagged docs; engineer needs to re-upload.
 *   * Null / Unknown / pre-engineer — the "become an engineer"
 *     onboarding nudge (verified status is terminal, so it doesn't
 *     surface the banner; the screen renders nothing in that case).
 *
 * Extracted so the per-state copy is unit-testable without the
 * Compose runtime that wraps the colors + click handler.
 */
internal data class HomeKycBannerCopy(val title: String, val subtitle: String)

/**
 * SLA-credits card subtitle on Home: "N SLA breach(es) in the last
 * 30 days. Tap to review." Singular/plural split on the breach count.
 *
 * Pin so a regression to always-"breaches" doesn't surface "1
 * breaches" on the most common single-breach case.
 */
internal fun slaCreditsCardSubtitle(breachCount: Int): String =
    if (breachCount == 1) {
        "1 SLA breach in the last 30 days. Tap to review."
    } else {
        "$breachCount SLA breaches in the last 30 days. Tap to review."
    }

/**
 * Title on the home SLA-credits card: "₹X credited for SLA misses".
 *
 * Pin the trailing "for SLA misses" — load-bearing context that
 * tells the hospital this is COMPENSATION owed by the engineer
 * (via the pool ledger), NOT a charge against them. A refactor that
 * dropped the "for SLA misses" suffix would leave "₹X credited"
 * ambiguous — "credited TO whom, BY whom"?
 *
 * Note: formatRupees already includes the ₹ prefix; this helper
 * composes the suffix only.
 */
internal fun slaCreditsCardTitle(totalCreditRupees: Double): String =
    "${formatRupees(totalCreditRupees)} credited for SLA misses"

/**
 * Compose the cash-survey question body for the bottom-sheet on
 * HomeHub. Embeds the public job number + engineer name so the user
 * has unambiguous context about which visit they're rating.
 *
 *   "Job RPR-00027 with Ravi Kumar just wrapped. Did the engineer
 *    ask for any payment outside the app?"
 *
 * Pinned regions:
 *   * Both interpolations are caller-supplied + non-null on this
 *     code path (the parent survey null-check happens upstream), so
 *     the helper trusts inputs.
 *   * Question phrasing pinned word-for-word — this is the
 *     trust-and-safety signal the founder uses to investigate
 *     cash-flag patterns; the wording was reviewed by product.
 */
internal fun cashSurveyQuestionBody(jobNumber: String, engineerName: String): String =
    "Job $jobNumber with $engineerName just wrapped. " +
        "Did the engineer ask for any payment outside the app?"

/**
 * Question prompt on the spot-audit sheet.
 *
 * Sibling of [cashSurveyQuestionBody] — both surface a freshly-completed
 * job's job number + engineer name and ask the hospital a quality
 * question. Critical pin: the FALLBACK strings distinguish the two:
 *
 *   - jobNumber → "RPR-${take(6)}" when null (same convention as the
 *     founder queue rows).
 *   - engineerName → "the engineer" (lowercase, definite article) when
 *     null. Sibling cashSurveyQuestionBody requires both fields
 *     non-null (the cash-survey caller gates upstream); this helper
 *     stays total because the spot-audit caller doesn't.
 *
 * Pin the literal "just wrapped" and "Rate the work." — concise prose
 * that doesn't pre-bias the answer (vs "Rate the quality" which
 * suggests there might be a quality issue).
 */
internal fun spotAuditQuestionBody(
    jobNumber: String?,
    repairJobId: String,
    engineerName: String?,
): String {
    val jobLabel = jobNumber ?: "RPR-${repairJobId.take(6)}"
    val engineerLabel = engineerName ?: "the engineer"
    return "Job $jobLabel with $engineerLabel just wrapped. Rate the work."
}

/**
 * Submit gate on the spot-audit rating sheet.
 *
 * Requires:
 *   1. rating in 1..5 (inclusive — both bounds; 0 = "no rating
 *      picked yet", 6+ = impossible)
 *   2. NOT currently submitting
 *
 * Pin the 1..5 range — server CHECK constraint on spot_audit_responses
 * matches; widening would surface server errors mid-action.
 */
internal fun canSubmitSpotAudit(rating: Int, submitting: Boolean): Boolean =
    rating in 1..5 && !submitting

/**
 * Role-aware empty-state copy for the Home hub's "Recent activity"
 * section. Each role points the user at their next concrete action
 * (Hospital → post a job; Engineer → find open jobs; everyone else
 * → generic "stuff appears here").
 *
 * Pinned regression: a previous version showed the same generic
 * "Your bookings, bids, and messages will appear here." for all
 * three roles. That stated the obvious without telling the user how
 * to get unstuck — role-aware copy points at the next CTA.
 */
internal fun homeRecentEmptyCopy(role: UserRole?): String = when (role) {
    UserRole.HOSPITAL ->
        "No bookings yet. Tap \"Book a repair engineer\" above to post your first job."
    UserRole.ENGINEER ->
        "No activity yet. Tap the Jobs tab to find open repair jobs you can bid on."
    else ->
        "Your bookings, bids, and messages will appear here."
}

internal fun homeKycBannerCopy(status: VerificationStatus?): HomeKycBannerCopy = when (status) {
    VerificationStatus.Pending -> HomeKycBannerCopy(
        title = "KYC under review",
        subtitle = "Usually 24h. We'll notify you.",
    )
    VerificationStatus.Rejected -> HomeKycBannerCopy(
        title = "KYC needs another try",
        subtitle = "Re-submit the missing docs to enter the queue.",
    )
    else -> HomeKycBannerCopy(
        title = "Become a verified engineer",
        subtitle = "Submit KYC to start bidding on jobs.",
    )
}
