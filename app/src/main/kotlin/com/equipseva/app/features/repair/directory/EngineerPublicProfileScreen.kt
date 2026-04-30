package com.equipseva.app.features.repair.directory

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen100
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.components.ServiceAreaMap
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerPublicProfileViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: EngineerDirectoryRepository,
    private val authRepository: com.equipseva.app.core.auth.AuthRepository,
    private val chatRepository: com.equipseva.app.core.data.chat.ChatRepository,
) : ViewModel() {
    private val engineerId: String = savedStateHandle[Routes.ENGINEER_PUBLIC_PROFILE_ARG_ID] ?: ""

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val profile: EngineerDirectoryRepository.PublicProfile? = null,
        val openingChat: Boolean = false,
    )

    sealed interface Effect {
        data class NavigateToChat(val conversationId: String) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = kotlinx.coroutines.channels.Channel<Effect>(kotlinx.coroutines.channels.Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            val dummy = DUMMY_PUBLIC_PROFILES[engineerId]
            if (dummy != null) {
                _state.update { it.copy(loading = false, profile = dummy) }
                return@launch
            }
            repo.fetchPublicProfile(engineerId)
                .onSuccess { p -> _state.update { it.copy(loading = false, profile = p) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun openChatWithEngineer() {
        val peerId = _state.value.profile?.userId
        if (peerId.isNullOrBlank() || _state.value.openingChat) return
        _state.update { it.copy(openingChat = true) }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<com.equipseva.app.core.auth.AuthSession.SignedIn>()
                .firstOrNull()
            val selfId = session?.userId
            if (selfId == null) {
                _state.update { it.copy(openingChat = false) }
                _effects.send(Effect.ShowMessage("Please sign in to start a chat"))
                return@launch
            }
            if (selfId == peerId) {
                _state.update { it.copy(openingChat = false) }
                _effects.send(Effect.ShowMessage("This is your own profile"))
                return@launch
            }
            chatRepository.getOrCreateDirect(selfUserId = selfId, peerUserId = peerId).fold(
                onSuccess = { convo ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.NavigateToChat(convo.id))
                },
                onFailure = { ex ->
                    _state.update { it.copy(openingChat = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }
}

private val DUMMY_PUBLIC_PROFILES: Map<String, EngineerDirectoryRepository.PublicProfile> = mapOf(
    "dummy-eng-1" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-1",
        userId = null,
        fullName = "Satish Naidu",
        avatarUrl = null,
        phone = "+91 98••• ••321",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda", "Suryapet"),
        specializations = listOf("Patient Monitors", "Ventilators", "Defibrillators"),
        brandsServiced = listOf("Philips", "GE", "Mindray"),
        oemTrainingBadges = listOf("Philips IntelliVue", "GE CARESCAPE"),
        experienceYears = 8,
        ratingAvg = 4.9,
        totalJobs = 142,
        completionRate = 98.0,
        hourlyRate = 1500.0,
        bio = "Independent biomedical engineer with 8 years experience servicing critical-care equipment across Nalgonda and Suryapet districts. Same-day onsite for ICU/OT equipment.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 30,
    ),
    "dummy-eng-2" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-2",
        userId = null,
        fullName = "Priyanka Reddy",
        avatarUrl = null,
        phone = "+91 98••• ••456",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda"),
        specializations = listOf("Surgical", "Anaesthesia", "OT equipment"),
        brandsServiced = listOf("Drager", "Medtronic"),
        oemTrainingBadges = listOf("Drager Anaesthesia"),
        experienceYears = 6,
        ratingAvg = 4.8,
        totalJobs = 67,
        completionRate = 100.0,
        hourlyRate = 1400.0,
        bio = "Specialist in OT and anaesthesia equipment. Certified by Drager. 6 years across multi-specialty hospitals in Nalgonda.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 20,
    ),
    "dummy-eng-3" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-3",
        userId = null,
        fullName = "Arjun Varma",
        avatarUrl = null,
        phone = "+91 98••• ••782",
        email = null,
        city = "Nalgonda",
        state = "Telangana",
        serviceAreas = listOf("Nalgonda"),
        specializations = listOf("Imaging", "Ultrasound", "X-ray"),
        brandsServiced = listOf("Siemens", "GE"),
        oemTrainingBadges = listOf("Siemens MRI"),
        experienceYears = 10,
        ratingAvg = 4.7,
        totalJobs = 203,
        completionRate = 96.0,
        hourlyRate = 1800.0,
        bio = "Senior imaging engineer — MRI/CT/ultrasound. 10 years across Telangana. Currently busy through next week.",
        isAvailable = false,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 50,
    ),
    "dummy-eng-4" to EngineerDirectoryRepository.PublicProfile(
        engineerId = "dummy-eng-4",
        userId = null,
        fullName = "Lakshmi Devi",
        avatarUrl = null,
        phone = "+91 98••• ••109",
        email = null,
        city = "Suryapet",
        state = "Telangana",
        serviceAreas = listOf("Suryapet", "Nalgonda"),
        specializations = listOf("Laboratory", "Centrifuges", "Analyzers"),
        brandsServiced = listOf("Roche", "Beckman"),
        oemTrainingBadges = emptyList(),
        experienceYears = 5,
        ratingAvg = 4.6,
        totalJobs = 54,
        completionRate = 94.0,
        hourlyRate = 1200.0,
        bio = "Lab equipment specialist — centrifuges, analyzers, biochem. Covers Suryapet/Nalgonda.",
        isAvailable = true,
        baseLatitude = null,
        baseLongitude = null,
        serviceRadiusKm = 40,
    ),
)

@Composable
fun EngineerPublicProfileScreen(
    onBack: () -> Unit,
    onRequestService: (engineerId: String) -> Unit,
    onOpenConversation: (conversationId: String) -> Unit = {},
    onShowMessage: (String) -> Unit = {},
    viewModel: EngineerPublicProfileViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is EngineerPublicProfileViewModel.Effect.NavigateToChat ->
                    onOpenConversation(effect.conversationId)
                is EngineerPublicProfileViewModel.Effect.ShowMessage ->
                    onShowMessage(effect.text)
            }
        }
    }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Engineer",
                onBack = onBack,
                right = {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .clickable { /* share */ },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Outlined.Share,
                            contentDescription = "Share",
                            tint = SevaInk700,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                },
            )
            Box(modifier = Modifier.weight(1f)) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.profile == null -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Profile unavailable",
                        subtitle = state.error ?: "This engineer is no longer listed.",
                    )
                    else -> ProfileBody(
                        p = state.profile!!,
                        onCall = { dial(context, state.profile!!.phone) },
                        onWhatsApp = { whatsapp(context, state.profile!!.phone) },
                    )
                }
            }
            // Sticky CTA bar
            if (state.profile != null) {
                Surface(color = Color.White) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(BorderDefault),
                        )
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            EsBtn(
                                text = if (state.openingChat) "Opening…" else "Message",
                                onClick = { viewModel.openChatWithEngineer() },
                                kind = EsBtnKind.Secondary,
                                size = EsBtnSize.Lg,
                                disabled = state.openingChat,
                                leading = {
                                    Icon(
                                        Icons.AutoMirrored.Outlined.Chat,
                                        contentDescription = null,
                                        tint = SevaInk700,
                                        modifier = Modifier.size(16.dp),
                                    )
                                },
                            )
                            Box(modifier = Modifier.weight(1f)) {
                                EsBtn(
                                    text = "Request this engineer",
                                    onClick = { onRequestService(state.profile!!.engineerId) },
                                    kind = EsBtnKind.Primary,
                                    size = EsBtnSize.Lg,
                                    full = true,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileBody(
    p: EngineerDirectoryRepository.PublicProfile,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
) {
    val hasRelationship = !p.phone.isNullOrBlank() || !p.email.isNullOrBlank()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hero block — white bg + 1dp bottom border, padding 8/16/16
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AvatarBlock(
                    initials = p.fullName.take(2).uppercase(),
                    avatarUrl = p.avatarUrl,
                    size = 64.dp,
                    online = p.isAvailable,
                )
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            p.fullName,
                            color = SevaInk900,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        InlineVerifiedBadge(small = false)
                    }
                    val locLine = listOfNotNull(
                        p.city?.takeIf { it.isNotBlank() },
                        p.state?.takeIf { it.isNotBlank() },
                    ).joinToString(", ")
                    if (locLine.isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(locLine, color = SevaInk500, fontSize = 12.sp)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        InlineStars(rating = p.ratingAvg, count = p.totalJobs)
                        Pill(
                            text = if (p.isAvailable) "Available" else "Busy",
                            kind = if (p.isAvailable) PillKind.Success else PillKind.Warn,
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
            Spacer(Modifier.height(12.dp))
            // 3-stat grid
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Hourly",
                    value = p.hourlyRate?.let { "₹${it.toInt()}" } ?: "—",
                    color = SevaInk900,
                )
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Jobs done",
                    value = p.totalJobs.toString(),
                    color = SevaInk900,
                )
                Stat(
                    modifier = Modifier.weight(1f),
                    label = "Completion",
                    value = run {
                        val pct = if (p.completionRate <= 1.0) p.completionRate * 100 else p.completionRate
                        "${pct.toInt()}%"
                    },
                    color = SevaGreen700,
                )
            }
        }
        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))

        // About
        if (!p.bio.isNullOrBlank()) {
            EsSection(title = "About") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Text(
                        p.bio,
                        color = SevaInk700,
                        fontSize = 13.sp,
                        lineHeight = 19.5.sp,
                    )
                }
            }
        }

        // Specializations — soft (green-50) chips
        if (!p.specializations.isNullOrEmpty()) {
            EsSection(title = "Specializations") {
                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                    ChipFlowSoft(items = p.specializations.orEmpty())
                }
            }
        }

        // Brands serviced — neutral (paper-2) chips
        if (!p.brandsServiced.isNullOrEmpty()) {
            EsSection(title = "Brands serviced") {
                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                    ChipFlowNeutral(items = p.brandsServiced.orEmpty())
                }
            }
        }

        // OEM training (only when present)
        if (!p.oemTrainingBadges.isNullOrEmpty()) {
            EsSection(title = "OEM training") {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    p.oemTrainingBadges.orEmpty().forEach { o ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Icon(
                                Icons.Outlined.Verified,
                                contentDescription = null,
                                tint = SevaGreen700,
                                modifier = Modifier.size(16.dp),
                            )
                            Text(o, color = SevaInk700, fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        // Service area
        if (p.baseLatitude != null && p.baseLongitude != null) {
            EsSection(title = "Service area") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Paper3),
                    ) {
                        ServiceAreaMap(
                            baseLatitude = p.baseLatitude,
                            baseLongitude = p.baseLongitude,
                            serviceRadiusKm = p.serviceRadiusKm,
                            engineerName = p.fullName,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Service radius: ${p.serviceRadiusKm ?: "—"} km",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        } else if (!p.serviceAreas.isNullOrEmpty() || !p.city.isNullOrBlank()) {
            EsSection(title = "Service area") {
                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Paper3),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "Map preview",
                            color = SevaInk500,
                            fontSize = 12.sp,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Service radius: ${p.serviceRadiusKm ?: 25} km",
                        color = SevaInk500,
                        fontSize = 12.sp,
                    )
                }
            }
        }

        // Contact section — only when relationship lit
        if (hasRelationship) {
            EsSection(title = "Contact") {
                if (!p.phone.isNullOrBlank()) {
                    ContactRow(
                        icon = Icons.Outlined.Phone,
                        title = p.phone,
                        subtitle = "Tap to call",
                        onClick = onCall,
                    )
                    ContactRow(
                        icon = Icons.AutoMirrored.Outlined.Chat,
                        title = "WhatsApp",
                        subtitle = "Open chat",
                        onClick = onWhatsApp,
                    )
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .padding(16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SevaInfo50)
                    .padding(12.dp),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Icon(
                        Icons.Outlined.Security,
                        contentDescription = null,
                        tint = SevaInfo500,
                        modifier = Modifier
                            .padding(top = 1.dp)
                            .size(16.dp),
                    )
                    Text(
                        "Phone and email are shown after you start a chat or have a past job with this engineer.",
                        color = SevaInfo500,
                        fontSize = 12.sp,
                        lineHeight = 17.sp,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun Stat(
    modifier: Modifier = Modifier,
    label: String,
    value: String,
    color: Color,
) {
    Column(modifier = modifier) {
        Text(label, fontSize = 11.sp, color = SevaInk500)
        Spacer(Modifier.height(2.dp))
        Text(
            value,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = color,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipFlowSoft(items: List<String>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { item ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(SevaGreen50)
                    .border(1.dp, SevaGreen100, RoundedCornerShape(999.dp))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(prettyKey(item), color = SevaGreen700, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipFlowNeutral(items: List<String>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { item ->
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(Paper2)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(item, color = SevaInk600, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun ContactRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = SevaGreen700, modifier = Modifier.size(18.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = SevaInk900, fontSize = 14.sp, fontWeight = FontWeight.Medium)
            Text(subtitle, color = SevaInk500, fontSize = 12.sp)
        }
    }
}

private fun dial(context: android.content.Context, phone: String?) {
    if (phone.isNullOrBlank()) {
        Toast.makeText(context, "Phone not available", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "No dialer app installed", Toast.LENGTH_SHORT).show()
    }
}

private fun whatsapp(context: android.content.Context, phone: String?) {
    if (phone.isNullOrBlank()) {
        Toast.makeText(context, "Phone not available", Toast.LENGTH_SHORT).show()
        return
    }
    val cleaned = phone.replace("+", "").replace(" ", "").replace("-", "")
    val msg = "Hi, I'd like to discuss a repair request from EquipSeva."
    val uri = Uri.parse("https://wa.me/$cleaned?text=" + Uri.encode(msg))
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "WhatsApp not installed", Toast.LENGTH_SHORT).show()
    }
}

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
