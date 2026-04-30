package com.equipseva.app.features.engineerprofile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.SevaWarning50

// Suggested specializations chip catalog. Toggling one updates the
// VM's comma-separated `specializations` string so save logic stays intact.
private val SPEC_CATALOG = listOf(
    "CT Scanner",
    "MRI",
    "X-Ray",
    "Ultrasound",
    "Ventilator",
    "ECG",
    "Defibrillator",
    "Anesthesia",
    "Patient Monitor",
    "Dialysis",
    "Endoscopy",
    "Lab Equipment",
)

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
            Box(modifier = Modifier.fillMaxSize().weight(1f)) {
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
            // Sticky bottom save bar — white bg, 1dp top border, 12dp/16dp padding.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White)
                    .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(0.dp))
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                EsBtn(
                    text = if (state.saving) "Saving…" else "Save changes",
                    onClick = viewModel::onSave,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !state.canSave,
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
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
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Bio (multiline)
        val bioLen = state.bio.trim().length
        val bioShort = bioLen < BIO_MIN_LEN
        EsField(
            value = state.bio,
            onChange = onBioChange,
            label = "Bio",
            type = EsFieldType.Multiline,
            hint = if (bioShort) "$bioLen/$BIO_MIN_LEN characters — ${BIO_MIN_LEN - bioLen} more to go"
            else "$bioLen characters. Hospitals see this on your profile.",
            error = if (bioShort && state.bio.isNotEmpty()) "Bio must be at least $BIO_MIN_LEN characters" else null,
            enabled = !state.saving,
        )

        // Hourly rate (₹) — Number
        EsField(
            value = state.hourlyRate,
            onChange = onHourlyRateChange,
            label = "Hourly rate (₹)",
            type = EsFieldType.Number,
            enabled = !state.saving,
        )

        // Years of experience — Number (preserved from VM contract)
        EsField(
            value = state.yearsExperience,
            onChange = onYearsChange,
            label = "Years of experience",
            type = EsFieldType.Number,
            enabled = !state.saving,
        )

        // Service areas — Text (preserved from VM contract; spec uses "service radius",
        // but VM persists a comma-separated list of areas. Keep the data shape stable.)
        EsField(
            value = state.serviceAreas,
            onChange = onServiceAreasChange,
            label = "Service areas",
            placeholder = "Hyderabad, Secunderabad, Cyberabad",
            hint = "Comma-separated list of cities or pincodes",
            enabled = !state.saving,
        )

        // Availability (Available / Busy buttons)
        Column {
            Text(
                text = "Availability",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk700,
                modifier = Modifier.padding(bottom = 8.dp),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AvailabilityButton(
                    text = "Available",
                    selected = state.isAvailable,
                    selectedBorder = SevaGreen700,
                    selectedBg = SevaGreen50,
                    enabled = !state.saving,
                    onClick = { onAvailableChange(true) },
                    modifier = Modifier.weight(1f),
                )
                AvailabilityButton(
                    text = "Busy",
                    selected = !state.isAvailable,
                    selectedBorder = SevaWarning500,
                    selectedBg = SevaWarning50,
                    enabled = !state.saving,
                    onClick = { onAvailableChange(false) },
                    modifier = Modifier.weight(1f),
                )
            }
        }

        // Specializations chips (FlowRow toggles)
        Column {
            Text(
                text = "Specializations",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk700,
                modifier = Modifier.padding(bottom = 8.dp),
            )
            val selectedSet = remember(state.specializations) {
                state.specializations.split(',').map { it.trim() }.filter { it.isNotBlank() }.toMutableSet()
            }
            // Union catalog with any pre-existing selections so prior values stay visible.
            val chips = remember(state.specializations) {
                (SPEC_CATALOG + selectedSet).distinct()
            }
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                chips.forEach { spec ->
                    val isOn = selectedSet.any { it.equals(spec, ignoreCase = true) }
                    EsChip(
                        text = spec,
                        active = isOn,
                        onClick = if (state.saving) null else {
                            {
                                val next = selectedSet.toMutableList().also { list ->
                                    val match = list.firstOrNull { it.equals(spec, ignoreCase = true) }
                                    if (match != null) list.remove(match) else list.add(spec)
                                }
                                onSpecializationsChange(next.joinToString(", "))
                            }
                        },
                    )
                }
            }
        }

        ErrorBanner(message = state.errorMessage)
    }
}

@Composable
private fun AvailabilityButton(
    text: String,
    selected: Boolean,
    selectedBorder: Color,
    selectedBg: Color,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(10.dp)
    val border = if (selected) selectedBorder else BorderDefault
    val bg = if (selected) selectedBg else Color.White
    Box(
        modifier = modifier
            .clip(shape)
            .background(bg)
            .border(width = 1.5.dp, color = border, shape = shape)
            .let { if (enabled) it.clickable(onClick = onClick) else it }
            .padding(vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
    }
}
