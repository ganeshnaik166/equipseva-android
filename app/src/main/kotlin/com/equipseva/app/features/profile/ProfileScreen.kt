package com.equipseva.app.features.profile

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.designsystem.components.BrandedPlaceholder
import com.equipseva.app.designsystem.components.DeleteAccountSheet
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SettingsSheet
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.ErrorBg
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.auth.UserRole

@Composable
fun ProfileScreen(
    onShowMessage: (String) -> Unit,
    onOpenMessages: () -> Unit = {},
    onOpenVerification: () -> Unit = {},
    onOpenAbout: () -> Unit = {},
    onOpenFavorites: () -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    onOpenChangePassword: () -> Unit = {},
    onOpenChangeEmail: () -> Unit = {},
    viewModel: ProfileViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val themeMode by viewModel.themeMode.collectAsStateWithLifecycle()
    val settingsOpen by viewModel.settingsOpen.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ProfileViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                is ProfileViewModel.Effect.ShareExport -> shareExportFile(context, effect.path)
            }
        }
    }

    Scaffold(topBar = { ESTopBar(title = "Profile") }) { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            when {
                state.loading && state.profile == null -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                state.profile == null -> {
                    ProfileErrorView(
                        message = state.errorMessage ?: "Profile not available",
                        onRetry = viewModel::onRefresh,
                        onSignOut = viewModel::onSignOut,
                        signingOut = state.signingOut,
                    )
                }
                else -> {
                    ProfileContent(
                        state = state,
                        themeMode = themeMode,
                        onEditRole = viewModel::onOpenRoleEditor,
                        onSignOut = viewModel::onSignOut,
                        onEditProfile = viewModel::onOpenEditProfile,
                        onOpenSettings = viewModel::onOpenSettings,
                        onOpenMessages = onOpenMessages,
                        onOpenVerification = onOpenVerification,
                        onOpenAbout = onOpenAbout,
                        onOpenFavorites = onOpenFavorites,
                        onOpenNotifications = onOpenNotifications,
                        onDeleteAccount = viewModel::onOpenDeleteAccount,
                        onExportData = viewModel::onExportMyData,
                        onOpenChangePassword = onOpenChangePassword,
                        onOpenChangeEmail = onOpenChangeEmail,
                    )
                }
            }
        }
    }

    if (state.roleEditorOpen) {
        RoleEditorSheet(
            currentRole = state.profile?.role,
            selected = state.roleEditorSelected,
            updating = state.roleUpdating,
            onSelect = viewModel::onRoleEditorSelect,
            onConfirm = viewModel::onRoleEditorConfirm,
            onDismiss = viewModel::onDismissRoleEditor,
        )
    }

    if (settingsOpen) {
        SettingsSheet(
            currentMode = themeMode,
            onSelectMode = viewModel::onThemeModeChange,
            onDismiss = viewModel::onDismissSettings,
        )
    }

    if (state.deleteAccountOpen) {
        DeleteAccountSheet(
            reason = state.deleteReason,
            deleting = state.deletingAccount,
            onReasonChange = viewModel::onDeleteReasonChange,
            onConfirm = viewModel::onConfirmDeleteAccount,
            onDismiss = viewModel::onDismissDeleteAccount,
        )
    }

    if (state.editProfileOpen) {
        EditProfileSheet(
            fullName = state.editFullName,
            phone = state.editPhone,
            saving = state.editSaving,
            error = state.editError,
            onFullNameChange = viewModel::onEditFullNameChange,
            onPhoneChange = viewModel::onEditPhoneChange,
            onSave = viewModel::onSaveEditProfile,
            onDismiss = viewModel::onDismissEditProfile,
        )
    }
}

@Composable
private fun ProfileContent(
    state: ProfileViewModel.UiState,
    themeMode: ThemeMode,
    onEditRole: () -> Unit,
    onSignOut: () -> Unit,
    onEditProfile: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenMessages: () -> Unit,
    onOpenVerification: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenNotifications: () -> Unit,
    onDeleteAccount: () -> Unit,
    onExportData: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
) {
    val profile = state.profile!!
    val isEngineer = profile.role == UserRole.ENGINEER
    val isHospital = profile.role == UserRole.HOSPITAL

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface50)
            .verticalScroll(rememberScrollState()),
    ) {
        // Header card with edit icon, avatar, name, role + verified chips, and secondary line.
        ProfileHeaderCard(
            displayName = profile.displayName,
            avatarUrl = profile.avatarUrl,
            role = profile.role,
            secondaryLine = buildSecondaryLine(profile, isEngineer),
            verified = profile.roleConfirmed,
            onEdit = onEditProfile,
        )
        Spacer(Modifier.height(Spacing.md))

        // Role switcher block (keeps existing functionality).
        Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
            RoleCard(
                role = profile.role,
                roleConfirmed = profile.roleConfirmed,
                onEdit = onEditRole,
                updating = state.roleUpdating,
            )
        }
        Spacer(Modifier.height(Spacing.md))

        // Organization (hospital/clinic) context if present.
        if (profile.organizationName != null || profile.locationLine != null) {
            Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                OrgCard(
                    orgName = profile.organizationName,
                    locationLine = profile.locationLine,
                )
            }
            Spacer(Modifier.height(Spacing.md))
        }

        // Settings rows list (role-specific).
        Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
            SettingsList(
                rows = buildSettingsRows(
                    isEngineer = isEngineer,
                    isHospital = isHospital,
                    themeMode = themeMode,
                    onOpenSettings = onOpenSettings,
                    onOpenVerification = onOpenVerification,
                    onOpenMessages = onOpenMessages,
                    onOpenAbout = onOpenAbout,
                    onOpenFavorites = onOpenFavorites,
                    onOpenNotifications = onOpenNotifications,
                    onOpenChangePassword = onOpenChangePassword,
                    onOpenChangeEmail = onOpenChangeEmail,
                    onSignOut = onSignOut,
                    signingOut = state.signingOut,
                    onDeleteAccount = onDeleteAccount,
                    deletingAccount = state.deletingAccount,
                    onExportData = onExportData,
                    exportingData = state.exportingData,
                ),
            )
        }

        Spacer(Modifier.height(Spacing.xl))
    }
}

private data class SettingsRow(
    val icon: ImageVector,
    val label: String,
    val trailing: String? = null,
    val chipLabel: String? = null,
    val chipTone: StatusTone = StatusTone.Neutral,
    val danger: Boolean = false,
    val enabled: Boolean = true,
    val onClick: (() -> Unit)? = null,
)

private fun buildSettingsRows(
    isEngineer: Boolean,
    isHospital: Boolean,
    themeMode: ThemeMode,
    onOpenSettings: () -> Unit,
    onOpenVerification: () -> Unit,
    onOpenMessages: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
    onSignOut: () -> Unit,
    signingOut: Boolean,
    onDeleteAccount: () -> Unit,
    deletingAccount: Boolean,
    onExportData: () -> Unit,
    exportingData: Boolean,
): List<SettingsRow> {
    val rows = mutableListOf<SettingsRow>()
    rows += SettingsRow(
        icon = Icons.Filled.Person,
        label = "Personal info",
        onClick = onOpenMessages, // messages row retained as generic "open" target for now
    )
    rows += SettingsRow(
        icon = Icons.Outlined.Notifications,
        label = "Notifications",
        onClick = onOpenNotifications,
    )
    if (isEngineer) {
        rows += SettingsRow(
            icon = Icons.Filled.AccountBalance,
            label = "Bank details",
            onClick = onOpenFavorites,
        )
        rows += SettingsRow(
            icon = Icons.Outlined.VerifiedUser,
            label = "Verification (KYC)",
            chipLabel = "Review",
            chipTone = StatusTone.Warn,
            onClick = onOpenVerification,
        )
    } else if (isHospital) {
        rows += SettingsRow(
            icon = Icons.Filled.LocationOn,
            label = "Addresses",
            onClick = onOpenFavorites,
        )
        rows += SettingsRow(
            icon = Icons.Filled.LocalHospital,
            label = "Hospital settings",
            onClick = onOpenMessages,
        )
    }
    rows += SettingsRow(
        icon = Icons.Filled.Translate,
        label = "Language",
        trailing = "English",
    )
    rows += SettingsRow(
        icon = Icons.Outlined.Palette,
        label = "Appearance",
        trailing = themeMode.displayLabel(),
        onClick = onOpenSettings,
    )
    rows += SettingsRow(
        icon = Icons.Outlined.Lock,
        label = "Change password",
        onClick = onOpenChangePassword,
    )
    rows += SettingsRow(
        icon = Icons.Outlined.Email,
        label = "Change email",
        onClick = onOpenChangeEmail,
    )
    rows += SettingsRow(
        icon = Icons.Outlined.Info,
        label = "About",
        onClick = onOpenAbout,
    )
    rows += SettingsRow(
        icon = Icons.Filled.CloudDownload,
        label = if (exportingData) "Preparing export…" else "Export my data",
        enabled = !exportingData,
        onClick = onExportData,
    )
    rows += SettingsRow(
        icon = Icons.AutoMirrored.Filled.Logout,
        label = if (signingOut) "Signing out…" else "Sign out",
        danger = true,
        enabled = !signingOut,
        onClick = onSignOut,
    )
    rows += SettingsRow(
        icon = Icons.Filled.DeleteForever,
        label = if (deletingAccount) "Deleting account…" else "Delete account",
        danger = true,
        enabled = !deletingAccount,
        onClick = onDeleteAccount,
    )
    return rows
}

private fun buildSecondaryLine(profile: com.equipseva.app.core.data.profile.Profile, isEngineer: Boolean): String? {
    val parts = buildList {
        profile.locationLine?.takeIf { it.isNotBlank() }?.let { add(it) }
        profile.organizationName
            ?.takeIf { !isEngineer && it.isNotBlank() && it != profile.locationLine }
            ?.let { add(it) }
    }
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}

@Composable
private fun ProfileHeaderCard(
    displayName: String,
    avatarUrl: String?,
    role: UserRole?,
    secondaryLine: String?,
    verified: Boolean,
    onEdit: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .padding(top = 24.dp, bottom = 28.dp),
    ) {
        // Bottom 1dp border approximated via an underlay strip.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .height(1.dp)
                .background(Surface200),
        )

        // Top-right edit button.
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(12.dp)
                .size(40.dp)
                .clip(CircleShape)
                .clickable(onClick = onEdit),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Edit,
                contentDescription = "Edit profile",
                tint = Ink700,
                modifier = Modifier.size(20.dp),
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            val avatarSize = 80.dp
            if (!avatarUrl.isNullOrBlank()) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .size(avatarSize)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                )
            } else {
                BrandedPlaceholder(
                    modifier = Modifier
                        .size(avatarSize)
                        .clip(CircleShape),
                    shape = CircleShape,
                    logoSize = 44.dp,
                )
            }
            Text(
                text = displayName,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val roleIcon = when (role) {
                    UserRole.ENGINEER -> Icons.Filled.Engineering
                    UserRole.HOSPITAL -> Icons.Filled.LocalHospital
                    else -> Icons.Filled.Person
                }
                StatusChip(
                    label = role?.displayName ?: "No role",
                    tone = StatusTone.Info,
                    icon = roleIcon,
                )
                if (verified) {
                    StatusChip(
                        label = "Verified",
                        tone = StatusTone.Success,
                        icon = Icons.Outlined.Verified,
                    )
                }
            }
            if (!secondaryLine.isNullOrBlank()) {
                Text(
                    text = secondaryLine,
                    fontSize = 13.sp,
                    color = Ink500,
                )
            }
        }
    }
}

@Composable
private fun SettingsList(rows: List<SettingsRow>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp)),
    ) {
        rows.forEachIndexed { index, row ->
            SettingsRowItem(row = row)
            if (index < rows.size - 1) {
                HorizontalDivider(color = Surface200, thickness = 1.dp)
            }
        }
    }
}

@Composable
private fun SettingsRowItem(row: SettingsRow) {
    val tileBg = if (row.danger) ErrorBg else Surface50
    val iconTint = if (row.danger) ErrorRed else Ink700
    val labelColor = if (row.danger) ErrorRed else Ink900
    val rowModifier = Modifier
        .fillMaxWidth()
        .let { if (row.enabled && row.onClick != null) it.clickable(onClick = row.onClick) else it }
        .padding(horizontal = 14.dp, vertical = 14.dp)

    Row(
        modifier = rowModifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(tileBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = row.icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(20.dp),
            )
        }
        Text(
            text = row.label,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (!row.enabled) Ink500 else labelColor,
            modifier = Modifier.weight(1f),
        )
        if (row.chipLabel != null) {
            StatusChip(label = row.chipLabel, tone = row.chipTone)
            Spacer(Modifier.size(Spacing.xs))
        }
        if (row.trailing != null) {
            Text(
                text = row.trailing,
                fontSize = 13.sp,
                color = Ink500,
            )
        }
        if (!row.danger) {
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = Ink500,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

private fun ThemeMode.displayLabel(): String = when (this) {
    ThemeMode.System -> "System"
    ThemeMode.Light -> "Light"
    ThemeMode.Dark -> "Dark"
}

@Composable
private fun RoleCard(
    role: UserRole?,
    roleConfirmed: Boolean,
    onEdit: () -> Unit,
    updating: Boolean,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Text(
                "Role",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink500,
                letterSpacing = 0.4.sp,
            )
            androidx.compose.foundation.layout.Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
                    Text(
                        role?.displayName ?: "Not set",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink900,
                    )
                    if (role != null) {
                        Text(
                            role.description,
                            fontSize = 12.sp,
                            color = Ink500,
                        )
                    }
                }
                AssistChip(
                    onClick = onEdit,
                    enabled = !updating,
                    label = { Text(if (role == null) "Choose" else "Change") },
                    leadingIcon = { Icon(Icons.Filled.Edit, contentDescription = null) },
                    colors = AssistChipDefaults.assistChipColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        labelColor = MaterialTheme.colorScheme.onPrimary,
                        leadingIconContentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                    border = null,
                )
            }
            if (!roleConfirmed && role != null) {
                Text(
                    "Role selection not yet confirmed on server.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

@Composable
private fun OrgCard(orgName: String?, locationLine: String?) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Text(
                "Organization",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink500,
                letterSpacing = 0.4.sp,
            )
            orgName?.takeIf { it.isNotBlank() }?.let {
                Text(it, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Ink900)
            }
            locationLine?.let {
                Text(
                    it,
                    fontSize = 13.sp,
                    color = Ink500,
                )
            }
        }
    }
}

@Composable
private fun ProfileErrorView(
    message: String,
    onRetry: () -> Unit,
    onSignOut: () -> Unit,
    signingOut: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Filled.Person,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(64.dp),
        )
        Text(message, style = MaterialTheme.typography.bodyLarge)
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(),
        ) {
            Icon(Icons.Filled.Refresh, contentDescription = null)
            Spacer(Modifier.size(Spacing.sm))
            Text("Retry")
        }
        OutlinedButton(
            onClick = onSignOut,
            enabled = !signingOut,
        ) {
            Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null)
            Spacer(Modifier.size(Spacing.sm))
            Text(if (signingOut) "Signing out…" else "Sign out")
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RoleEditorSheet(
    currentRole: UserRole?,
    selected: UserRole?,
    updating: Boolean,
    onSelect: (UserRole) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                "Change your role",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "This changes what you see across the app. You can switch again anytime.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            HorizontalDivider()
            UserRole.entries.forEach { role ->
                RoleOption(
                    role = role,
                    selected = role == selected,
                    current = role == currentRole,
                    onClick = { onSelect(role) },
                )
            }
            Button(
                onClick = onConfirm,
                enabled = selected != null && !updating,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (updating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = Color.White,
                    )
                    Spacer(Modifier.size(Spacing.sm))
                    Text("Saving…")
                } else {
                    Text("Save")
                }
            }
        }
    }
}

@Composable
private fun RoleOption(
    role: UserRole,
    selected: Boolean,
    current: Boolean,
    onClick: () -> Unit,
) {
    val border = if (selected) {
        BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
    } else {
        BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    }
    OutlinedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Spacing.md),
        border = border,
        colors = CardDefaults.outlinedCardColors(
            containerColor = if (selected) {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
            } else {
                MaterialTheme.colorScheme.surface
            },
        ),
    ) {
        androidx.compose.foundation.layout.Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
            )
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xxs)) {
                androidx.compose.foundation.layout.Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Text(role.displayName, style = MaterialTheme.typography.titleMedium)
                    if (current) {
                        AssistChip(
                            onClick = onClick,
                            label = { Text("Current") },
                            colors = AssistChipDefaults.assistChipColors(
                                containerColor = MaterialTheme.colorScheme.primaryContainer,
                                labelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                            ),
                            border = null,
                        )
                    }
                }
                Text(
                    role.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditProfileSheet(
    fullName: String,
    phone: String,
    saving: Boolean,
    error: String?,
    onFullNameChange: (String) -> Unit,
    onPhoneChange: (String) -> Unit,
    onSave: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                "Edit profile",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "Email can't be changed here — it's tied to your account.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            HorizontalDivider()
            OutlinedTextField(
                value = fullName,
                onValueChange = onFullNameChange,
                label = { Text("Full name") },
                singleLine = true,
                enabled = !saving,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = phone,
                onValueChange = onPhoneChange,
                label = { Text("Phone (optional)") },
                singleLine = true,
                enabled = !saving,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                modifier = Modifier.fillMaxWidth(),
            )
            if (error != null) {
                Text(
                    error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                OutlinedButton(
                    onClick = onDismiss,
                    enabled = !saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = onSave,
                    enabled = !saving,
                    modifier = Modifier.weight(1f),
                ) {
                    if (saving) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = Color.White,
                        )
                        Spacer(Modifier.size(Spacing.sm))
                        Text("Saving…")
                    } else {
                        Text("Save")
                    }
                }
            }
        }
    }
}

private fun shareExportFile(context: Context, absolutePath: String) {
    val file = java.io.File(absolutePath)
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )
    val share = Intent(Intent.ACTION_SEND).apply {
        type = "application/json"
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_SUBJECT, "EquipSeva data export")
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    val chooser = Intent.createChooser(share, "Share my data export").apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(chooser)
}
