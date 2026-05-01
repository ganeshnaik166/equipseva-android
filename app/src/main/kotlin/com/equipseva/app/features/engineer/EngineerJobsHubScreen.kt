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
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.LocalOffer
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
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
    onBack: (() -> Unit)? = null,
    onAvailableJobs: () -> Unit,
    onMyBids: () -> Unit,
    onActiveWork: () -> Unit,
    onEarnings: () -> Unit,
    onEditProfile: () -> Unit,
    onServiceLocation: () -> Unit,
    onSubmitKyc: () -> Unit,
    onSignIn: () -> Unit,
    viewModel: EngineerJobsHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            EsTopBar(title = "Engineer Jobs", onBack = onBack)

            when (state.status) {
                EngineerJobsHubViewModel.Status.Loading ->
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(40.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator()
                    }
                EngineerJobsHubViewModel.Status.NotSignedIn ->
                    OnboardingHero(
                        title = "Sign in to start taking jobs",
                        body = "Create an account, complete engineer KYC, and start receiving repair leads in your district.",
                        ctaLabel = "Sign in / Sign up",
                        onCta = onSignIn,
                    )
                EngineerJobsHubViewModel.Status.NotEngineer ->
                    OnboardingHero(
                        title = "Become a repairman",
                        body = "Submit a quick KYC (Aadhaar, PAN, qualification) so hospitals know you're verified.",
                        ctaLabel = "Submit KYC",
                        onCta = onSubmitKyc,
                    )
                EngineerJobsHubViewModel.Status.Pending ->
                    OnboardingHero(
                        title = "KYC under review",
                        body = "We're verifying your documents. You'll get a push when approved (usually under 24h).",
                        ctaLabel = null,
                        onCta = {},
                    )
                EngineerJobsHubViewModel.Status.Rejected ->
                    OnboardingHero(
                        title = "KYC rejected — try again",
                        body = "Open KYC to see the rejection reason and resubmit. Most rejections are fixed by uploading a clearer photo.",
                        ctaLabel = "Open KYC",
                        onCta = onSubmitKyc,
                    )
                EngineerJobsHubViewModel.Status.Verified -> Unit
            }

            if (state.status == EngineerJobsHubViewModel.Status.Verified) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    HubTile(
                        icon = Icons.Outlined.Bolt,
                        title = "Available jobs",
                        desc = "Nearby repair leads in your radius",
                        onClick = onAvailableJobs,
                    )
                    HubTile(
                        icon = Icons.Outlined.LocalOffer,
                        title = "My bids",
                        desc = "Bids you've placed",
                        onClick = onMyBids,
                    )
                    HubTile(
                        icon = Icons.Outlined.Build,
                        title = "Active work",
                        desc = "Jobs in progress",
                        onClick = onActiveWork,
                    )
                    HubTile(
                        icon = Icons.Outlined.CurrencyRupee,
                        title = "Earnings",
                        desc = "Payouts and history",
                        onClick = onEarnings,
                    )
                    HubTile(
                        icon = Icons.Outlined.LocationOn,
                        title = "Service location",
                        desc = "Move your base on the map",
                        onClick = onServiceLocation,
                    )
                    HubTile(
                        icon = Icons.Outlined.Person,
                        title = "Edit profile",
                        desc = "Bio, rate, service area",
                        onClick = onEditProfile,
                    )
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun OnboardingHero(
    title: String,
    body: String,
    ctaLabel: String?,
    onCta: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 40.dp),
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
                imageVector = Icons.Outlined.Shield,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(32.dp),
            )
        }
        Spacer(Modifier.height(20.dp))
        Text(
            text = title,
            style = EsType.H4,
            color = SevaInk900,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = body,
            style = EsType.BodySm,
            color = SevaInk600,
            textAlign = TextAlign.Center,
        )
        if (ctaLabel != null) {
            Spacer(Modifier.height(24.dp))
            EsBtn(
                text = ctaLabel,
                onClick = onCta,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
            )
        }
    }
}

@Composable
private fun HubTile(
    icon: ImageVector,
    title: String,
    desc: String,
    onClick: () -> Unit,
    badge: String? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = SevaGreen700, modifier = Modifier.size(20.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(text = desc, style = EsType.Caption, color = SevaInk500)
        }
        if (badge != null) {
            Pill(text = badge, kind = PillKind.Warn)
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(18.dp),
        )
    }
}
