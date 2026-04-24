package com.equipseva.app.features.engineerprofile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.BrandedPlaceholder
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

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

    Scaffold(
        topBar = {
            ESBackTopBar(
                title = "Engineer profile",
                onBack = onBack,
                backEnabled = !state.saving,
            )
        },
        bottomBar = {
            if (!state.loading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Surface0)
                        .border(1.dp, Surface200, MaterialTheme.shapes.extraSmall)
                        .padding(Spacing.lg),
                ) {
                    PrimaryButton(
                        label = if (state.saving) "Saving…" else "Save changes",
                        onClick = viewModel::onSave,
                        enabled = state.canSave,
                        loading = state.saving,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        },
    ) { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
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
                )
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
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        AvatarHeader()

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
    }
}

@Composable
private fun AvatarHeader() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = Spacing.xs, bottom = Spacing.lg),
        contentAlignment = Alignment.Center,
    ) {
        Box(modifier = Modifier.size(96.dp), contentAlignment = Alignment.BottomEnd) {
            BrandedPlaceholder(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape),
                shape = CircleShape,
                logoSize = 52.dp,
            )
            // Camera overlay button — brand-600 bg, white border, white icon.
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(BrandGreen)
                    .border(2.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.PhotoCamera,
                    contentDescription = "Change photo",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
    Spacer(Modifier.height(Spacing.xs))
}
