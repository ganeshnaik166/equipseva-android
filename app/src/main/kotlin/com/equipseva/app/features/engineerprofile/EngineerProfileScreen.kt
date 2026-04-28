package com.equipseva.app.features.engineerprofile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.Icon
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EngineerProfileScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: EngineerProfileViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is EngineerProfileViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                EngineerProfileViewModel.Effect.NavigateBack -> onBack()
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Edit profile",
                onBack = onBack.takeIf { !state.saving } ?: {},
            )
            Box(modifier = Modifier.weight(1f)) {
                if (state.loading) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else {
                    EngineerProfileForm(
                        state = state,
                        onHourlyRateChange = viewModel::onHourlyRateChange,
                        onYearsChange = viewModel::onYearsChange,
                        onServiceAreasChange = viewModel::onServiceAreasChange,
                        onSpecializationsChange = viewModel::onSpecializationsChange,
                        onBioChange = viewModel::onBioChange,
                        onAvailableChange = viewModel::onAvailableChange,
                        onSave = viewModel::onSave,
                        email = state.email,
                        phone = state.phone,
                    )
                }
            }
        }
    }
}

@Composable
private fun EngineerProfileForm(
    state: EngineerProfileViewModel.UiState,
    onHourlyRateChange: (String) -> Unit,
    onYearsChange: (String) -> Unit,
    onServiceAreasChange: (String) -> Unit,
    onSpecializationsChange: (String) -> Unit,
    onBioChange: (String) -> Unit,
    onAvailableChange: (Boolean) -> Unit,
    onSave: () -> Unit,
    email: String?,
    phone: String?,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        StatsHeader(
            jobs = state.totalJobs ?: 0,
            rating = state.ratingAvg,
            onTime = state.completionRate,
        )

        SectionHeader(title = "Contact details")
        ContactCard(email = email, phone = phone)

        SectionHeader(title = "Rates & experience")

        OutlinedTextField(
            value = state.hourlyRate,
            onValueChange = onHourlyRateChange,
            label = { Text("Hourly rate (INR)") },
            singleLine = true,
            enabled = !state.saving,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth(),
        )

        OutlinedTextField(
            value = state.yearsExperience,
            onValueChange = onYearsChange,
            label = { Text("Years of experience") },
            singleLine = true,
            enabled = !state.saving,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth(),
        )

        SectionHeader(title = "Coverage")

        OutlinedTextField(
            value = state.serviceAreas,
            onValueChange = onServiceAreasChange,
            label = { Text("Service areas") },
            placeholder = { Text("Hyderabad, Secunderabad, Cyberabad") },
            supportingText = { Text("Comma-separated list of cities or pincodes") },
            enabled = !state.saving,
            modifier = Modifier.fillMaxWidth(),
        )

        OutlinedTextField(
            value = state.specializations,
            onValueChange = onSpecializationsChange,
            label = { Text("Specializations") },
            placeholder = { Text("CT scanner, MRI, X-ray") },
            supportingText = { Text("Comma-separated list of equipment you service") },
            enabled = !state.saving,
            modifier = Modifier.fillMaxWidth(),
        )

        SectionHeader(title = "About you")

        val bioLen = state.bio.trim().length
        val bioShort = bioLen < BIO_MIN_LEN
        OutlinedTextField(
            value = state.bio,
            onValueChange = onBioChange,
            label = { Text("Bio") },
            supportingText = {
                Text(
                    text = if (bioShort) {
                        "$bioLen/$BIO_MIN_LEN characters — ${BIO_MIN_LEN - bioLen} more to go"
                    } else {
                        "$bioLen characters. Hospitals see this on your profile."
                    },
                    color = if (bioShort) MaterialTheme.colorScheme.error
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            },
            isError = bioShort && state.bio.isNotEmpty(),
            enabled = !state.saving,
            minLines = 4,
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Available for new jobs", style = MaterialTheme.typography.bodyLarge)
                Text(
                    if (state.isAvailable) "Hospitals can request you" else "You're hidden from search",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = state.isAvailable,
                onCheckedChange = onAvailableChange,
                enabled = !state.saving,
            )
        }

        ErrorBanner(message = state.errorMessage)

        PrimaryButton(
            label = if (state.saving) "Saving…" else "Save",
            onClick = onSave,
            enabled = state.canSave,
            loading = state.saving,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun StatsHeader(jobs: Int, rating: Double?, onTime: Double?) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StatTile(
            value = jobs.toString(),
            label = "Jobs",
            modifier = Modifier.weight(1f),
        )
        StatTile(
            value = rating?.let { "%.1f".format(it) } ?: "—",
            label = "Rating",
            modifier = Modifier.weight(1f),
        )
        StatTile(
            value = onTime?.let { "${(it * 100).toInt()}%" } ?: "—",
            label = "On-time",
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun ContactCard(email: String?, phone: String?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(14.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        ContactRow(icon = Icons.Filled.Phone, label = phone ?: "Add a phone number from your profile settings", strong = !phone.isNullOrBlank())
        ContactRow(icon = Icons.Filled.Email, label = email ?: "Add an email from your profile settings", strong = !email.isNullOrBlank())
        Text(
            text = "Hospitals can call, WhatsApp, and email you on these once your KYC is verified.",
            fontSize = 11.sp,
            color = SevaInk500,
        )
    }
}

@Composable
private fun ContactRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    strong: Boolean,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = if (strong) SevaGreen700 else SevaInk500)
        Text(
            text = label,
            fontSize = 13.sp,
            color = if (strong) SevaInk900 else SevaInk500,
            fontWeight = if (strong) FontWeight.SemiBold else FontWeight.Normal,
        )
    }
}

@Composable
private fun StatTile(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(SevaGreen50)
            .padding(vertical = 14.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = value,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = SevaGreen900,
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = SevaInk500,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.4.sp,
        )
    }
}
