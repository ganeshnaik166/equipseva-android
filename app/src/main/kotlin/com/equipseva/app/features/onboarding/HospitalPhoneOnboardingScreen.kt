package com.equipseva.app.features.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.profile.AddPhoneViewModel
import com.equipseva.app.features.profile.addPhoneLengthHint

/**
 * v0.3.4 — post-signup phone collection gate for hospital admins.
 *
 * Reuses [AddPhoneViewModel] (same Supabase write to profiles.phone)
 * but presents the input as an onboarding step:
 *   - no Back affordance — role is already written server-side and
 *     popping back to RoleSelect would leave a half-configured account
 *     (role set, phone missing). System Back is swallowed by
 *     [BackHandler] for the same reason.
 *   - on successful save, [onDone] pops the auth graph so AppNavGraph's
 *     session observer can swap to the main host.
 *
 * Phone is mandatory for Exotel call masking during repair jobs;
 * collecting at signup time avoids the silent-failure prone async
 * banner that lived on Home before v0.3.4.
 */
@Composable
fun HospitalPhoneOnboardingScreen(
    onDone: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: AddPhoneViewModel = hiltViewModel(),
) {
    // Block hardware/system Back: see KDoc above.
    BackHandler(enabled = true) { /* swallow */ }

    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is AddPhoneViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                AddPhoneViewModel.Effect.Done -> onDone()
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            // EsTopBar with no back arrow — the lambda is wired to a
            // no-op since this is an onboarding gate, not a sub-route
            // the user can leave by tapping the chevron.
            EsTopBar(title = "Add your phone number", onBack = { /* no-op */ })
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    "One last step",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                )
                Text(
                    "We need your mobile number to coordinate active jobs. " +
                        "Calls between you and the engineer route through EquipSeva " +
                        "— your real number stays private.",
                    fontSize = 13.sp,
                    color = SevaInk500,
                )
                val lengthHint = addPhoneLengthHint(
                    hasError = state.error != null,
                    phoneLength = state.phone.length,
                )
                OutlinedTextField(
                    value = state.phone,
                    onValueChange = viewModel::onPhoneChange,
                    label = { Text("Phone (e.g. +919999999999)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Phone,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(
                        onDone = {
                            if (!state.saving && state.phone.length >= 11) viewModel.onSave()
                        },
                    ),
                    isError = state.error != null,
                    supportingText = (state.error ?: lengthHint)?.let { { Text(it) } },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                EsBtn(
                    text = if (state.saving) "Saving…" else "Continue",
                    onClick = viewModel::onSave,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = state.saving || state.phone.length < 11,
                )
            }
        }
    }
}
