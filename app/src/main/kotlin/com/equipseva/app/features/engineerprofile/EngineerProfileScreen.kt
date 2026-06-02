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

// Round 321 — chip catalog source-of-truth must be the
// public.equipment_category enum on the server. The prior list used
// free-form display strings ("CT Scanner", "ECG", "Patient Monitor")
// that aren't valid enum members; any engineer who tapped a chip
// and saved would have hit a 22P02 invalid_input_value at upsert
// against engineers.specializations (which is equipment_category[]).
//
// Source of truth: RepairEquipmentCategory.entries (already mirrors
// pg_enum). Chip text uses .displayName; selection state stores
// .storageKey so save sends valid enum values.
internal val SPEC_CATALOG: List<String> =
    com.equipseva.app.core.data.repair.RepairEquipmentCategory.entries
        .map { it.storageKey }
        .filter { it != "other" }

internal fun specDisplayName(storageKey: String): String =
    com.equipseva.app.core.data.repair.RepairEquipmentCategory
        .fromKey(storageKey).displayName

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
        // Visibility hint — when either of the two gates is unset
        // (hourly rate, specialization), the engineer is hidden from
        // the hospital directory. Reinforces the Home banner so the
        // engineer knows exactly which fields unlock visibility once
        // they land on this screen.
        val rateIsSet = state.hourlyRate.toDoubleOrNull()?.let { it > 0.0 } == true
        val specsIsSet = state.specializations.split(',').any { it.isNotBlank() }
        if (!rateIsSet || !specsIsSet) {
            DirectoryVisibilityHint(rateIsSet = rateIsSet, specsIsSet = specsIsSet)
        }

        // Bio (multiline)
        val bioLen = state.bio.trim().length
        EsField(
            value = state.bio,
            onChange = onBioChange,
            label = "Bio",
            type = EsFieldType.Multiline,
            hint = bioHintLine(bioLen, BIO_MIN_LEN),
            error = bioErrorLine(bioLen, state.bio.isNotEmpty(), BIO_MIN_LEN),
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

        // Service areas — Text. Hospitals filter the directory by
        // Telangana *district* (Hyderabad, Nalgonda, Suryapet,
        // Warangal, Khammam), and the SQL matches each chip against
        // this list. The previous placeholder ("Hyderabad,
        // Secunderabad, Cyberabad") plus hint ("cities or pincodes")
        // suggested localities or PINs would work — they don't, only
        // the district names the directory chip row enumerates.
        EsField(
            value = state.serviceAreas,
            onChange = onServiceAreasChange,
            label = "Service areas",
            placeholder = "Hyderabad, Rangareddy, Medak",
            hint = "Comma-separated Telangana districts. Hospitals filtering by district see you when one matches.",
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
                        // Round 321 — chip shows the display name; the
                        // underlying state always stores the enum storage
                        // key so save can't send an invalid value.
                        text = specDisplayName(spec),
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

/**
 * Top-of-form info row that closes the loop on the Home directory-
 * visibility banner. Tells the engineer exactly which field(s) gate
 * their visibility, reinforcing the banner copy they tapped from. Same
 * gate logic as [com.equipseva.app.features.repair.directory.EngineerDirectoryViewModel]'s
 * `isBookable` predicate.
 */
@Composable
private fun DirectoryVisibilityHint(rateIsSet: Boolean, specsIsSet: Boolean) {
    val message = when {
        !rateIsSet && !specsIsSet ->
            "Your profile is hidden from hospitals. Set an hourly rate and pick at least one specialization below to appear in the directory."
        !rateIsSet ->
            "Set an hourly rate below — hospitals don't see profiles without a rate."
        else ->
            "Pick at least one specialization below — hospitals search by equipment type and won't see profiles without one."
    }
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SevaWarning50)
            .border(width = 1.dp, color = SevaWarning500, shape = shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = message,
            fontSize = 12.sp,
            color = SevaInk900,
        )
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

/**
 * Bio character-count hint on the engineer-profile form.
 *
 * Two branches:
 *   - bioLen < minLen → "N/M characters — K more to go" (U+2014
 *     em-dash separator + remaining count). Pin the "K more to go"
 *     phrasing — the engineer-facing instruction frames the work
 *     remaining, not the deficit.
 *   - bioLen >= minLen → "N characters. Hospitals see this on your
 *     profile." (the why — load-bearing motivation for filling out
 *     a proper bio).
 *
 * Pin both branches verbatim — a refactor that removed the period
 * after "characters" in the long-form branch (just "N characters
 * Hospitals see…") would reduce readability.
 */
internal fun bioHintLine(bioLen: Int, minLen: Int): String =
    if (bioLen < minLen) {
        "$bioLen/$minLen characters — ${minLen - bioLen} more to go"
    } else {
        "$bioLen characters. Hospitals see this on your profile."
    }

/**
 * Bio error line on the engineer-profile form.
 *
 * Returns null when there's no error to show. Critical gate: error
 * surfaces ONLY when BOTH conditions hold:
 *   1. bioLen < minLen (the bio is too short)
 *   2. bioNonEmpty (the field has SOMETHING in it)
 *
 * Pin condition 2 — pin so an empty field stays clean (no error
 * before the engineer has even typed). The hint communicates the
 * minimum requirement; the error only fires once they've started
 * typing and are below the threshold.
 *
 * Pin the literal "Bio must be at least N characters" — a refactor
 * to "Bio is too short" would lose the actionable threshold.
 */
internal fun bioErrorLine(bioLen: Int, bioNonEmpty: Boolean, minLen: Int): String? =
    if (bioLen < minLen && bioNonEmpty) "Bio must be at least $minLen characters" else null

