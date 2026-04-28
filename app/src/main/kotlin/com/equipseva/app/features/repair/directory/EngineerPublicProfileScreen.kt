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
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Inbox
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.components.ServiceAreaMap
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerPublicProfileViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: EngineerDirectoryRepository,
) : ViewModel() {
    private val engineerId: String = savedStateHandle[Routes.ENGINEER_PUBLIC_PROFILE_ARG_ID] ?: ""

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val profile: EngineerDirectoryRepository.PublicProfile? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repo.fetchPublicProfile(engineerId)
                .onSuccess { p -> _state.update { it.copy(loading = false, profile = p) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun EngineerPublicProfileScreen(
    onBack: () -> Unit,
    onRequestService: (engineerId: String) -> Unit,
    onMessage: (engineerId: String) -> Unit = {},
    viewModel: EngineerPublicProfileViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Engineer", onBack = onBack)
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
                        onEmail = { email(context, state.profile!!.email, state.profile!!.fullName) },
                    )
                }
            }
            // Sticky CTA bar
            if (state.profile != null) {
                Surface(color = Color.White) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        EsBtn(
                            text = "Message",
                            onClick = { onMessage(state.profile!!.engineerId) },
                            kind = EsBtnKind.Secondary,
                            size = EsBtnSize.Lg,
                            leading = {
                                Icon(
                                    Icons.AutoMirrored.Filled.Chat,
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

@Composable
private fun ProfileBody(
    p: EngineerDirectoryRepository.PublicProfile,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onEmail: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // White hero card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
                .padding(16.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(CircleShape)
                        .background(SevaGreen50),
                    contentAlignment = Alignment.Center,
                ) {
                    val img = p.avatarUrl
                    if (!img.isNullOrBlank()) {
                        AsyncImage(
                            model = img,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize().clip(CircleShape),
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        )
                    } else {
                        Text(
                            p.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                            color = SevaGreen900,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(p.fullName, color = SevaInk900, style = EsType.H4)
                        Icon(
                            imageVector = Icons.Filled.Verified,
                            contentDescription = "Verified",
                            tint = SevaGreen700,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                    val locLine = listOfNotNull(p.city, p.state).joinToString(" · ").ifBlank { null }
                    if (locLine != null) {
                        Text(locLine, color = SevaInk500, style = EsType.Caption)
                    }
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            Icon(Icons.Filled.Star, contentDescription = null, tint = SevaGlowRaw, modifier = Modifier.size(13.dp))
                            Text(
                                "${"%.1f".format(p.ratingAvg)} · ${p.totalJobs} jobs",
                                color = SevaInk700,
                                fontSize = 12.sp,
                            )
                        }
                        Pill(
                            text = if (p.isAvailable) "Available" else "Busy",
                            kind = if (p.isAvailable) PillKind.Success else PillKind.Warn,
                        )
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
            Spacer(Modifier.height(12.dp))
            // 3-stat grid
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat(modifier = Modifier.weight(1f), label = "Hourly", value = p.hourlyRate?.let { "₹${it.toInt()}" } ?: "—", color = SevaInk900)
                Stat(modifier = Modifier.weight(1f), label = "Jobs done", value = p.totalJobs.toString(), color = SevaInk900)
                Stat(modifier = Modifier.weight(1f), label = "Completion", value = "${(p.completionRate * 100).toInt()}%", color = SevaGreen700)
            }
        }

        // About
        if (!p.bio.isNullOrBlank()) {
            ProfileSection(title = "About") {
                Text(p.bio, style = EsType.BodySm, color = SevaInk700)
            }
        }

        // Specializations
        if (!p.specializations.isNullOrEmpty()) {
            ProfileSection(title = "Specializations") {
                ChipFlow(items = p.specializations.orEmpty())
            }
        }

        // Brands
        if (!p.brandsServiced.isNullOrEmpty()) {
            ProfileSection(title = "Brands serviced") {
                ChipFlow(items = p.brandsServiced.orEmpty())
            }
        }

        // Service area
        if (p.baseLatitude != null && p.baseLongitude != null) {
            ProfileSection(title = "Service area") {
                ServiceAreaMap(
                    baseLatitude = p.baseLatitude,
                    baseLongitude = p.baseLongitude,
                    serviceRadiusKm = p.serviceRadiusKm,
                    engineerName = p.fullName,
                    modifier = Modifier,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "Service radius: ${p.serviceRadiusKm} km",
                    style = EsType.Caption,
                    color = SevaInk500,
                )
            }
        } else if (!p.serviceAreas.isNullOrEmpty() || !p.city.isNullOrBlank()) {
            ProfileSection(title = "Service area") {
                val all = listOfNotNull(p.city) + p.serviceAreas.orEmpty()
                Text(all.joinToString(" · "), style = EsType.BodySm, color = SevaInk700)
            }
        }

        // Contact section — gated by relationship; server returns phone/email
        // only when the hospital has a chat or past job with the engineer.
        val hasContact = !p.phone.isNullOrBlank() || !p.email.isNullOrBlank()
        if (hasContact) {
            ProfileSection(title = "Contact") {
                ContactRow(
                    icon = Icons.Filled.Call,
                    title = p.phone ?: "Phone unavailable",
                    subtitle = "Tap to call",
                    enabled = !p.phone.isNullOrBlank(),
                    onClick = onCall,
                )
                ContactRow(
                    icon = Icons.AutoMirrored.Filled.Chat,
                    title = "WhatsApp",
                    subtitle = "Open chat",
                    enabled = !p.phone.isNullOrBlank(),
                    onClick = onWhatsApp,
                )
                ContactRow(
                    icon = Icons.Filled.Email,
                    title = p.email ?: "Email unavailable",
                    subtitle = "Send email",
                    enabled = !p.email.isNullOrBlank(),
                    onClick = onEmail,
                )
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
                        Icons.Filled.Build,
                        contentDescription = null,
                        tint = SevaInfo500,
                        modifier = Modifier.size(16.dp).padding(top = 2.dp),
                    )
                    Text(
                        "Phone and email are shown after you start a chat or have a past job with this engineer.",
                        style = EsType.Caption,
                        color = SevaInfo500,
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun Stat(modifier: Modifier = Modifier, label: String, value: String, color: Color) {
    Column(modifier = modifier) {
        Text(label, fontSize = 11.sp, color = SevaInk500)
        Spacer(Modifier.height(2.dp))
        Text(value, style = EsType.H5, color = color)
    }
}

@Composable
private fun ProfileSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, style = EsType.H5, color = SevaInk900)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            content()
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun ChipFlow(items: List<String>) {
    androidx.compose.foundation.layout.FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { item ->
            EsChip(text = prettyKey(item))
        }
    }
}

@Composable
private fun ContactRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = SevaGreen700, modifier = Modifier.size(18.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = EsType.Body, color = SevaInk900)
            Text(subtitle, style = EsType.Caption, color = SevaInk500)
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

private fun email(context: android.content.Context, address: String?, name: String) {
    if (address.isNullOrBlank()) {
        Toast.makeText(context, "Email not available", Toast.LENGTH_SHORT).show()
        return
    }
    val intent = Intent(Intent.ACTION_SENDTO).apply {
        data = Uri.parse("mailto:$address")
        putExtra(Intent.EXTRA_SUBJECT, "Service request via EquipSeva")
        putExtra(
            Intent.EXTRA_TEXT,
            "Hi $name,\n\nI found your profile on EquipSeva and would like to discuss a repair request.\n\nThanks.",
        )
    }
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "No email app installed", Toast.LENGTH_SHORT).show()
    }
}

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
