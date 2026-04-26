package com.equipseva.app.features.engineer

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerJobsHubViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
) : ViewModel() {
    enum class Status { Loading, NotSignedIn, NotEngineer, Pending, Rejected, Verified }

    data class UiState(
        val status: Status = Status.Loading,
        val displayName: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> refresh(session.userId)
                    AuthSession.SignedOut -> _state.update { UiState(status = Status.NotSignedIn) }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    private suspend fun refresh(userId: String) {
        engineerRepository.fetchByUserId(userId)
            .onSuccess { eng ->
                val s = when (eng?.verificationStatus?.name?.lowercase()) {
                    null -> Status.NotEngineer
                    "verified" -> Status.Verified
                    "rejected" -> Status.Rejected
                    else -> Status.Pending
                }
                _state.update { it.copy(status = s) }
            }
            .onFailure { _state.update { it.copy(status = Status.NotEngineer) } }
    }
}

@Composable
fun EngineerJobsHubScreen(
    onBack: () -> Unit,
    onAvailableJobs: () -> Unit,
    onMyBids: () -> Unit,
    onActiveWork: () -> Unit,
    onEarnings: () -> Unit,
    onEditProfile: () -> Unit,
    onSubmitKyc: () -> Unit,
    onSignIn: () -> Unit,
    viewModel: EngineerJobsHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Engineer jobs", onBack = onBack) }) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Surface50)
                .verticalScroll(rememberScrollState()),
        ) {
            Hero()
            Spacer(Modifier.height(Spacing.md))
            when (state.status) {
                EngineerJobsHubViewModel.Status.Loading ->
                    Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                EngineerJobsHubViewModel.Status.NotSignedIn ->
                    Onboarding(
                        title = "Sign in to start taking jobs",
                        body = "Create an account, complete engineer KYC, and start receiving repair leads in your district.",
                        ctaLabel = "Sign in / Sign up",
                        onCta = onSignIn,
                    )
                EngineerJobsHubViewModel.Status.NotEngineer ->
                    Onboarding(
                        title = "Become a repairman",
                        body = "Three steps: 1) Submit KYC docs (Aadhaar, degree). 2) Pick service area + brands. 3) Wait for founder approval (24h).",
                        ctaLabel = "Submit KYC",
                        onCta = onSubmitKyc,
                    )
                EngineerJobsHubViewModel.Status.Pending ->
                    StatusBanner(
                        title = "KYC under review",
                        body = "We're verifying your documents. You'll get a push when approved (usually < 24h).",
                        bg = WarningBg,
                        fg = Warning,
                        icon = Icons.Filled.Warning,
                    )
                EngineerJobsHubViewModel.Status.Rejected ->
                    Onboarding(
                        title = "KYC rejected — try again",
                        body = "Open KYC to see the rejection reason and resubmit. Most rejections are fixed by uploading a clearer photo.",
                        ctaLabel = "Open KYC",
                        onCta = onSubmitKyc,
                    )
                EngineerJobsHubViewModel.Status.Verified -> Unit
            }

            val gateOpen = state.status == EngineerJobsHubViewModel.Status.Verified
            if (gateOpen) {
                Spacer(Modifier.height(Spacing.sm))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    HubTile(
                        title = "Available jobs",
                        tagline = "Browse open repair requests near you",
                        icon = Icons.Filled.Build,
                        onClick = onAvailableJobs,
                    )
                    HubTile(
                        title = "My bids",
                        tagline = "Track every bid you've placed",
                        icon = Icons.Filled.Description,
                        onClick = onMyBids,
                    )
                    HubTile(
                        title = "Active work",
                        tagline = "Jobs you've been assigned",
                        icon = Icons.Filled.CheckCircle,
                        onClick = onActiveWork,
                    )
                    HubTile(
                        title = "Earnings",
                        tagline = "This month + lifetime payouts",
                        icon = Icons.Filled.Payments,
                        onClick = onEarnings,
                    )
                    HubTile(
                        title = "Edit profile",
                        tagline = "Bio, service areas, brands, hourly rate",
                        icon = Icons.Filled.Person,
                        onClick = onEditProfile,
                    )
                }
            }
            Spacer(Modifier.height(Spacing.xl))
        }
    }
}

@Composable
private fun Hero() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(BrandGreen, BrandGreenDeep)))
            .padding(horizontal = Spacing.lg, vertical = 22.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(AccentLimeSoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Engineering, contentDescription = null, tint = AccentLime, modifier = Modifier.size(32.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text("Engineer jobs", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Pick up jobs · bid · earn", color = Color.White.copy(alpha = 0.85f), fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun Onboarding(
    title: String,
    body: String,
    ctaLabel: String,
    onCta: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.md)
            .clip(RoundedCornerShape(16.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(16.dp))
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(title, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 17.sp)
        Text(body, color = Ink700, fontSize = 13.sp, lineHeight = 18.sp)
        Spacer(Modifier.height(4.dp))
        Button(onClick = onCta, modifier = Modifier.fillMaxWidth()) {
            Text(ctaLabel, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun StatusBanner(
    title: String,
    body: String,
    bg: Color,
    fg: Color,
    icon: ImageVector,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = fg, modifier = Modifier.size(20.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = fg, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(body, color = fg.copy(alpha = 0.85f), fontSize = 12.sp, lineHeight = 16.sp)
        }
    }
}

@Composable
private fun HubTile(
    title: String,
    tagline: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(AccentLimeSoft),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = BrandGreen, modifier = Modifier.size(28.dp))
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text(tagline, color = Ink500, fontSize = 12.sp, lineHeight = 15.sp)
        }
        Text("›", fontSize = 22.sp, color = Ink500)
    }
}
