package com.equipseva.app.features.auth

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Build
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectEffect
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectError
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectState

/**
 * The host refreshes its authoritative session gate after [onRoleSaved].
 * [onShowMessage] and [onBack] are retained for source compatibility. This
 * required setup step has an explicit sign-out exit, not a back navigation.
 */
@Suppress("UNUSED_PARAMETER")
@Composable
fun RoleSelectScreen(
    onShowMessage: (String) -> Unit,
    onBack: () -> Unit = {},
    viewModel: RoleSelectViewModel = hiltViewModel(),
    onRoleSaved: () -> Unit = {},
    onSignOut: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val currentOnRoleSaved by rememberUpdatedState(onRoleSaved)
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                RoleSelectEffect.RoleSaved -> currentOnRoleSaved()
            }
        }
    }
    RoleSelectContent(
        state = state,
        onRoleSelected = viewModel::onRoleSelected,
        onConfirm = viewModel::onConfirm,
        onCheckSavedRole = viewModel::onCheckSavedRole,
        onSignOut = {
            viewModel.cancelPendingSave()
            onSignOut()
        },
    )
}

/** All content and actions remain reachable with a small window or large text. */
@Composable
internal fun RoleSelectContent(
    state: RoleSelectState,
    onRoleSelected: (UserRole) -> Unit,
    onConfirm: () -> Unit,
    onCheckSavedRole: () -> Unit,
    onSignOut: () -> Unit,
) {
    val error = when (state.error) {
        RoleSelectError.SessionUnavailable -> stringResource(R.string.role_picker_error_session)
        RoleSelectError.Network -> stringResource(R.string.role_picker_error_network)
        RoleSelectError.SaveFailed -> stringResource(R.string.role_picker_error_save)
        null -> null
    }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Box(
            modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.systemBars),
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 600.dp)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = stringResource(R.string.role_picker_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = stringResource(R.string.role_picker_intro),
                    style = EsType.Body,
                    color = SevaInk600,
                )
                if (error != null) {
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite },
                    ) {
                        Text(
                            text = error,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            style = EsType.Body,
                            modifier = Modifier.padding(16.dp),
                        )
                    }
                }
                Column(
                    modifier = Modifier.fillMaxWidth().selectableGroup(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    state.roles.forEach { role ->
                        RoleCard(
                            role = role,
                            selected = role == state.selected,
                            enabled = !state.form.submitting && !state.saved,
                            onClick = { onRoleSelected(role) },
                        )
                    }
                }
                if (state.saved) {
                    Text(
                        text = stringResource(R.string.role_picker_saved),
                        style = EsType.Body,
                        color = SevaGreen700,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                    )
                }
                Button(
                    onClick = if (state.saved) onCheckSavedRole else onConfirm,
                    enabled = state.saved || state.canConfirm,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)
                        .semantics { liveRegion = LiveRegionMode.Polite },
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SevaGreen700),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
                ) {
                    if (state.form.submitting) {
                        CircularProgressIndicator(
                            color = SevaInk500,
                            strokeWidth = 2.dp,
                            modifier = Modifier.padding(end = 8.dp).size(20.dp).clearAndSetSemantics {},
                        )
                    }
                    Text(
                        text = stringResource(
                            when {
                                state.form.submitting -> R.string.role_picker_saving
                                state.saved -> R.string.role_picker_check_again
                                state.error != null -> R.string.role_picker_try_again
                                else -> R.string.role_picker_save_continue
                            },
                        ),
                        style = EsType.Label,
                    )
                }
                TextButton(
                    onClick = onSignOut,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    colors = ButtonDefaults.textButtonColors(contentColor = SevaInk600),
                ) {
                    Text(stringResource(R.string.role_picker_sign_out), style = EsType.Label)
                }
                Text(
                    text = stringResource(R.string.role_picker_sign_out_hint),
                    style = EsType.BodySm,
                    color = SevaInk600,
                )
            }
        }
    }
}

private data class RoleVisual(
    val icon: ImageVector,
    @StringRes val label: Int,
    @StringRes val description: Int,
)

private fun UserRole.visual(): RoleVisual? = when (this) {
    UserRole.HOSPITAL -> RoleVisual(
        Icons.Filled.Apartment,
        R.string.role_picker_hospital,
        R.string.role_picker_hospital_description,
    )
    UserRole.ENGINEER -> RoleVisual(
        Icons.Filled.Build,
        R.string.role_picker_engineer,
        R.string.role_picker_engineer_description,
    )
    else -> null
}

@Composable
private fun RoleCard(
    role: UserRole,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val visual = role.visual() ?: return
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 72.dp)
            .clip(shape)
            .background(if (selected) SevaGreen50 else Color.White)
            .border(1.5.dp, if (selected) SevaGreen700 else BorderDefault, shape)
            .selectable(
                selected = selected,
                enabled = enabled,
                role = Role.RadioButton,
                onClick = onClick,
            )
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = visual.icon,
            contentDescription = null,
            tint = if (selected) SevaGreen700 else SevaInk600,
            modifier = Modifier.size(28.dp),
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = stringResource(visual.label),
                style = EsType.Body,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(
                text = stringResource(visual.description),
                style = EsType.BodySm,
                color = SevaInk600,
            )
        }
        RadioButton(
            selected = selected,
            onClick = null,
            enabled = enabled,
            colors = RadioButtonDefaults.colors(selectedColor = SevaGreen700),
        )
    }
}
