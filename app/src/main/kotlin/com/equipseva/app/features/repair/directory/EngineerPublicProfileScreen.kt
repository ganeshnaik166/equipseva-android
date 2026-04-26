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
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
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
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
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
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed to load") } }
        }
    }
}

@Composable
fun EngineerPublicProfileScreen(
    onBack: () -> Unit,
    onRequestService: (engineerId: String) -> Unit,
    viewModel: EngineerPublicProfileViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    Scaffold(topBar = { ESBackTopBar(title = "Engineer profile", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
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
                    onRequestService = { onRequestService(state.profile!!.engineerId) },
                    onCall = {
                        val phone = state.profile?.phone
                        if (phone.isNullOrBlank()) {
                            Toast.makeText(context, "Phone not available", Toast.LENGTH_SHORT).show()
                        } else {
                            try {
                                context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")))
                            } catch (_: ActivityNotFoundException) {
                                Toast.makeText(context, "No dialer app installed", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    onWhatsApp = {
                        val phone = state.profile?.phone
                        if (phone.isNullOrBlank()) {
                            Toast.makeText(context, "Phone not available", Toast.LENGTH_SHORT).show()
                        } else {
                            val cleaned = phone.replace("+", "").replace(" ", "").replace("-", "")
                            val msg = "Hi, I'd like to discuss a repair request from EquipSeva."
                            val uri = Uri.parse(
                                "https://wa.me/$cleaned?text=" + Uri.encode(msg),
                            )
                            try {
                                context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                            } catch (_: ActivityNotFoundException) {
                                Toast.makeText(context, "WhatsApp not installed", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    onEmail = {
                        val email = state.profile?.email
                        if (email.isNullOrBlank()) {
                            Toast.makeText(context, "Email not available", Toast.LENGTH_SHORT).show()
                        } else {
                            val name = state.profile?.fullName ?: "Engineer"
                            val intent = Intent(Intent.ACTION_SENDTO).apply {
                                data = Uri.parse("mailto:$email")
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
                    },
                )
            }
        }
    }
}

@Composable
private fun ProfileBody(
    p: EngineerDirectoryRepository.PublicProfile,
    onRequestService: () -> Unit,
    onCall: () -> Unit,
    onWhatsApp: () -> Unit,
    onEmail: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hero
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.verticalGradient(listOf(BrandGreen, BrandGreenDeep)))
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Box(
                    modifier = Modifier.size(72.dp).clip(CircleShape).background(AccentLimeSoft),
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
                            color = BrandGreenDeep,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(p.fullName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                        // Public profile RPC gates to verification_status='verified',
                        // so reaching this screen means the engineer is verified.
                        Icon(
                            imageVector = Icons.Filled.Verified,
                            contentDescription = "Verified engineer",
                            tint = AccentLime,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    Text(
                        "Senior Biomedical Engineer · ${p.experienceYears} yrs",
                        color = Color.White.copy(alpha = 0.85f),
                        fontSize = 13.sp,
                    )
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Filled.Star, contentDescription = null, tint = AccentLime, modifier = Modifier.size(14.dp))
                        Text(
                            "${"%.1f".format(p.ratingAvg)} · ${p.totalJobs} jobs",
                            color = Color.White.copy(alpha = 0.9f),
                            fontSize = 12.sp,
                        )
                    }
                }
            }
        }

        // Quick action bar — 3 ways to reach the engineer.
        // Buttons render even when phone/email are missing; the click handler
        // shows a toast in that case so the hospital understands why nothing
        // happened. (Verified engineers should always have both fields.)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface0)
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            ActionButton(
                icon = Icons.Filled.Call,
                label = "Call",
                enabled = !p.phone.isNullOrBlank(),
                onClick = onCall,
                modifier = Modifier.weight(1f),
            )
            ActionButton(
                icon = Icons.AutoMirrored.Filled.Chat,
                label = "WhatsApp",
                enabled = !p.phone.isNullOrBlank(),
                onClick = onWhatsApp,
                modifier = Modifier.weight(1f),
            )
            ActionButton(
                icon = Icons.Filled.Email,
                label = "Email",
                enabled = !p.email.isNullOrBlank(),
                onClick = onEmail,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(Spacing.sm))

        // Service areas
        if (!p.serviceAreas.isNullOrEmpty() || !p.city.isNullOrBlank()) {
            SectionCard(title = "Service areas", icon = Icons.Filled.LocationOn) {
                val all = listOfNotNull(p.city) + p.serviceAreas.orEmpty()
                Text(all.joinToString(" · "), color = Ink700, fontSize = 13.sp)
            }
        }

        // Specializations
        if (!p.specializations.isNullOrEmpty()) {
            SectionCard(title = "Specializations", icon = Icons.Filled.Build) {
                ChipFlow(items = p.specializations.orEmpty())
            }
        }

        // Brand expertise
        if (!p.brandsServiced.isNullOrEmpty()) {
            SectionCard(title = "Brand expertise", icon = Icons.Filled.Build) {
                ChipFlow(items = p.brandsServiced.orEmpty())
            }
        }

        // About
        if (!p.bio.isNullOrBlank()) {
            SectionCard(title = "About", icon = Icons.Filled.Build) {
                Text(p.bio, color = Ink700, fontSize = 13.sp, lineHeight = 18.sp)
            }
        }

        // Pricing
        SectionCard(title = "Pricing", icon = Icons.Filled.Build) {
            val rate = p.hourlyRate
            Text(
                if (rate == null) "Quote on request" else "₹${rate.toInt()}/hr · diagnostic visit + repair work",
                color = Ink700,
                fontSize = 13.sp,
            )
        }

        Spacer(Modifier.height(Spacing.lg))

        // Primary CTA
        Button(
            onClick = onRequestService,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        ) {
            Text("Send a service request", fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(Spacing.xl))
    }
}

@Composable
private fun ActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 8.dp),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
        Text(label, modifier = Modifier.padding(start = 6.dp), fontSize = 13.sp)
    }
}

@Composable
private fun SectionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = 6.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, contentDescription = null, tint = BrandGreen, modifier = Modifier.size(16.dp))
            Text(title, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
        content()
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
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(AccentLimeSoft)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                Text(prettyKey(item), color = BrandGreenDeep, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
