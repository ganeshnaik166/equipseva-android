package com.equipseva.app.features.profile

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Shield
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
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
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SettingsSheet
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
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
    onOpenNotifications: () -> Unit = {},
    onOpenBankDetails: () -> Unit = {},
    onOpenAddresses: () -> Unit = {},
    onOpenHospitalSettings: () -> Unit = {},
    onOpenFounderDashboard: () -> Unit = {},
    onOpenAddPhone: () -> Unit = {},
    onOpenChangePassword: () -> Unit = {},
    onOpenChangeEmail: () -> Unit = {},
    onOpenEarnings: () -> Unit = {},
    onOpenMyRepairJobs: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenPublicPreview: (engineerId: String) -> Unit = {},
    onOpenMaintenanceContracts: () -> Unit = {},
    // PR-D41 — hospital self-view of dispute filing history.
    onOpenMyDisputes: () -> Unit = {},
    onSwitchService: () -> Unit = {},
    onSignIn: () -> Unit = {},
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
                ProfileViewModel.Effect.NavigateHome -> onSwitchService()
            }
        }
    }

    Scaffold(
        topBar = {
            EsTopBar(
                title = "Profile",
                right = {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .clickable(onClick = onOpenNotifications),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Notifications,
                            contentDescription = "Notifications",
                            tint = Ink700,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                },
            )
        },
        containerColor = com.equipseva.app.designsystem.theme.PaperDefault,
    ) { inner ->
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
                state.isSignedOut -> {
                    // PRD: signed-out users can browse Marketplace freely. The
                    // Profile tab now shows a sign-in CTA instead of an error,
                    // so a tap from the bottom nav doesn't look broken.
                    SignedOutPrompt(onSignIn = onSignIn)
                }
                state.profile == null -> {
                    // Authenticated, but the profile bootstrap returned null
                    // — usually an RLS denial on the embedded organization
                    // join, occasionally a fresh signup before the row
                    // hydrates. Surface the actual error so the user knows
                    // what's wrong, plus a retry. Sign-in CTA is gone
                    // because it would bounce a signed-in user straight
                    // back to Home.
                    val msg = state.errorMessage
                    Column(
                        modifier = Modifier.fillMaxSize().padding(Spacing.lg),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            if (msg != null) "Couldn't load your profile" else "Finishing setup…",
                            fontWeight = FontWeight.Bold,
                            color = Ink900,
                        )
                        Spacer(Modifier.height(Spacing.sm))
                        Text(
                            msg ?: "We're loading your profile. Tap retry if this doesn't clear.",
                            color = Ink500,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        )
                        Spacer(Modifier.height(Spacing.md))
                        androidx.compose.material3.Button(
                            onClick = {
                                state.profile?.id?.let { viewModel.onRefresh() }
                                    ?: viewModel.onRetryFromAuth()
                            },
                        ) {
                            Text("Retry")
                        }
                    }
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
                        onOpenNotifications = onOpenNotifications,
                        onOpenBankDetails = onOpenBankDetails,
                        onOpenAddresses = onOpenAddresses,
                        onOpenHospitalSettings = onOpenHospitalSettings,
                        onOpenFounderDashboard = onOpenFounderDashboard,
                        onDeleteAccount = viewModel::onOpenDeleteAccount,
                        onExportData = viewModel::onOpenExportConfirm,
                        onOpenAddPhone = onOpenAddPhone,
                        onOpenChangePassword = onOpenChangePassword,
                        onOpenChangeEmail = onOpenChangeEmail,
                        onOpenEarnings = onOpenEarnings,
                        onOpenMyRepairJobs = onOpenMyRepairJobs,
                        onOpenHelp = onOpenHelp,
                        onOpenPublicPreview = onOpenPublicPreview,
                        onOpenMaintenanceContracts = onOpenMaintenanceContracts,
                        onOpenMyDisputes = onOpenMyDisputes,
                        onSwitchService = viewModel::onToggleRoleAndGoHome,
                        onPickAvatar = viewModel::uploadAvatar,
                    )
                }
            }
        }
    }

    if (settingsOpen) {
        SettingsSheet(
            currentMode = themeMode,
            onSelectMode = viewModel::onThemeModeChange,
            onDismiss = viewModel::onDismissSettings,
        )
    }

    // Role-editor bottom sheet — opens from the Account-type card.
    // VM-backed since 2026-04 but the trigger went unrendered until
    // 2026-05-08; multi-role users couldn't reach the engineer side
    // of the app once they confirmed a hospital-first signup.
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

    if (state.exportConfirmOpen) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = viewModel::onDismissExportConfirm,
            title = { androidx.compose.material3.Text("Export your data?") },
            text = {
                androidx.compose.material3.Text(
                    "We'll bundle your profile, addresses, messages and repair-job history into a JSON file and open the share sheet so you can save or send it. Anyone you share it with will be able to read it.",
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = viewModel::onExportMyData) {
                    androidx.compose.material3.Text("Export")
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = viewModel::onDismissExportConfirm) {
                    androidx.compose.material3.Text("Cancel")
                }
            },
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
            onChangePhone = {
                viewModel.onDismissEditProfile()
                onOpenAddPhone()
            },
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
    onOpenNotifications: () -> Unit,
    onOpenBankDetails: () -> Unit,
    onOpenAddresses: () -> Unit,
    onOpenHospitalSettings: () -> Unit,
    onOpenFounderDashboard: () -> Unit,
    onDeleteAccount: () -> Unit,
    onExportData: () -> Unit,
    onOpenAddPhone: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
    onOpenEarnings: () -> Unit,
    onOpenMyRepairJobs: () -> Unit,
    onOpenHelp: () -> Unit,
    onOpenPublicPreview: (engineerId: String) -> Unit,
    onOpenMaintenanceContracts: () -> Unit,
    onOpenMyDisputes: () -> Unit,
    onSwitchService: () -> Unit,
    onPickAvatar: (Uri) -> Unit,
) {
    val profile = state.profile!!
    val isEngineer = profile.role == UserRole.ENGINEER
    val isHospital = profile.role == UserRole.HOSPITAL
    val isSupplier = profile.role == UserRole.SUPPLIER
    val isManufacturer = profile.role == UserRole.MANUFACTURER
    val isLogistics = profile.role == UserRole.LOGISTICS
    val isFounder = profile.isFounder()
    val avatarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? -> if (uri != null) onPickAvatar(uri) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface50)
            .verticalScroll(rememberScrollState()),
    ) {
        ProfileHero(
            displayName = profile.displayName,
            email = profile.email,
            avatarUrl = profile.avatarUrl,
            role = profile.role,
            engineerStatus = state.engineerStatus,
            engineerKycSubmitted = state.engineerKycSubmitted,
            avatarUploading = state.avatarUploading,
            onPickAvatar = { avatarPicker.launch("image/*") },
            onEdit = onEditProfile,
        )

        // PR-D30 — engineer-side cash-flag suspension banner. Renders only
        // when isEngineer + an active auto-suspension. Tells engineer the
        // count + the official path to clear (admin reviews via PR-D25).
        state.mySuspension?.let { sus ->
            EngineerSuspensionBanner(suspension = sus)
        }

        val sections = buildProfileSections(
            isEngineer = isEngineer,
            isHospital = isHospital,
            isSupplier = isSupplier,
            isManufacturer = isManufacturer,
            isLogistics = isLogistics,
            isFounder = isFounder,
            phone = profile.phone,
            themeMode = themeMode,
            activeRoleLabel = profile.role?.displayName ?: "Not set",
            onOpenSettings = onOpenSettings,
            onOpenVerification = onOpenVerification,
            onOpenMessages = onOpenMessages,
            onOpenAbout = onOpenAbout,
            onOpenNotifications = onOpenNotifications,
            onOpenPersonalInfo = onEditProfile,
            onOpenBankDetails = onOpenBankDetails,
            onOpenAddresses = onOpenAddresses,
            onOpenHospitalSettings = onOpenHospitalSettings,
            onOpenFounderDashboard = onOpenFounderDashboard,
            onOpenAddPhone = onOpenAddPhone,
            onOpenChangePassword = onOpenChangePassword,
            onOpenChangeEmail = onOpenChangeEmail,
            onOpenEarnings = onOpenEarnings,
            onOpenMyRepairJobs = onOpenMyRepairJobs,
            onOpenHelp = onOpenHelp,
            ownEngineerId = state.ownEngineerId,
            engineerStatus = state.engineerStatus,
            engineerKycSubmitted = state.engineerKycSubmitted,
            onOpenPublicPreview = onOpenPublicPreview,
            onOpenMaintenanceContracts = onOpenMaintenanceContracts,
            onOpenMyDisputes = onOpenMyDisputes,
            onSwitchService = onSwitchService,
            onSignOut = onSignOut,
            signingOut = state.signingOut,
            onDeleteAccount = onDeleteAccount,
            deletingAccount = state.deletingAccount,
            onExportData = onExportData,
            exportingData = state.exportingData,
        )

        sections.forEach { section ->
            if (section.title == "Danger zone") {
                AccountTypeSection(role = profile.role, onEditRole = onEditRole)
            }
            ProfileSectionView(section)
        }

        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun EngineerSuspensionBanner(
    suspension: com.equipseva.app.core.data.engineers.EngineerRepository.MySuspension,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(com.equipseva.app.designsystem.theme.SevaDanger50)
            .border(1.dp, com.equipseva.app.designsystem.theme.SevaDanger500, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(
                imageVector = Icons.Outlined.Block,
                contentDescription = null,
                tint = com.equipseva.app.designsystem.theme.SevaDanger500,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = "Account paused — under review",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = com.equipseva.app.designsystem.theme.SevaDanger500,
            )
        }
        Text(
            text = suspension.reason
                ?: "${suspension.flagCount90d} hospital cash-payment flags in the last 90 days. EquipSeva paused your availability while we review.",
            fontSize = 12.sp,
            color = com.equipseva.app.designsystem.theme.SevaInk700,
        )
        suspension.suspendedAt?.let {
            Text(
                text = "Paused: " + it.take(19).replace('T', ' '),
                fontSize = 11.sp,
                color = com.equipseva.app.designsystem.theme.SevaInk500,
            )
        }
        Text(
            text = "Reach support to walk through the flagged jobs and reactivate.",
            fontSize = 12.sp,
            color = com.equipseva.app.designsystem.theme.SevaInk700,
        )
    }
}

@Composable
private fun AccountTypeSection(role: UserRole?, onEditRole: () -> Unit) {
    // role can legitimately be null while the profile is mid-fetch — in
    // that case we want a neutral label, not a misleading "Hospital admin"
    // (which used to appear because the old `else` branch swallowed null
    // and ENGINEER-not-equal cases together).
    val title = when (role) {
        UserRole.ENGINEER -> "Biomedical engineer"
        UserRole.HOSPITAL -> "Hospital admin"
        null -> "Loading…"
        else -> role.displayName
    }
    val subtitle = when (role) {
        UserRole.ENGINEER -> "You bid on and complete repair jobs"
        UserRole.HOSPITAL -> "You book engineers for repairs"
        null -> ""
        else -> role.description
    }
    Text(
        text = "Account type",
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = (-0.18).sp,
        color = com.equipseva.app.designsystem.theme.SevaInk900,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 20.dp),
    )
    Spacer(Modifier.height(12.dp))
    Column(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(androidx.compose.ui.graphics.Color.White)
                .border(1.dp, com.equipseva.app.designsystem.theme.BorderDefault, RoundedCornerShape(12.dp))
                .clickable(enabled = role != null, onClick = onEditRole)
                .padding(horizontal = 14.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Person,
                contentDescription = null,
                tint = com.equipseva.app.designsystem.theme.SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = com.equipseva.app.designsystem.theme.SevaInk900,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = com.equipseva.app.designsystem.theme.SevaInk500,
                )
            }
            if (role != null) {
                Icon(
                    imageVector = Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = com.equipseva.app.designsystem.theme.SevaInk500,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

private data class ProfileSection(
    val title: String,
    val rows: List<SettingsRow>,
)

@Composable
private fun ProfileSectionView(section: ProfileSection) {
    // Section header — 18sp/700 ink-900, 20dp top padding, 12dp bottom
    // marginal spacer. Mirrors `shared.jsx:Section`.
    Text(
        text = section.title,
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = (-0.18).sp,
        color = com.equipseva.app.designsystem.theme.SevaInk900,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 20.dp),
    )
    Spacer(Modifier.height(12.dp))
    Column(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        SettingsList(rows = section.rows)
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

private fun buildProfileSections(
    isEngineer: Boolean,
    isHospital: Boolean,
    isSupplier: Boolean,
    isManufacturer: Boolean,
    isLogistics: Boolean,
    isFounder: Boolean,
    phone: String?,
    themeMode: ThemeMode,
    activeRoleLabel: String,
    onOpenSettings: () -> Unit,
    onOpenVerification: () -> Unit,
    onOpenMessages: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenPersonalInfo: () -> Unit,
    onOpenBankDetails: () -> Unit,
    onOpenAddresses: () -> Unit,
    onOpenHospitalSettings: () -> Unit,
    onOpenFounderDashboard: () -> Unit,
    onOpenAddPhone: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
    onOpenEarnings: () -> Unit,
    onOpenMyRepairJobs: () -> Unit,
    onOpenHelp: () -> Unit,
    ownEngineerId: String?,
    engineerStatus: VerificationStatus?,
    engineerKycSubmitted: Boolean,
    onOpenPublicPreview: (engineerId: String) -> Unit,
    onOpenMaintenanceContracts: () -> Unit,
    onOpenMyDisputes: () -> Unit,
    onSwitchService: () -> Unit,
    onSignOut: () -> Unit,
    signingOut: Boolean,
    onDeleteAccount: () -> Unit,
    deletingAccount: Boolean,
    onExportData: () -> Unit,
    exportingData: Boolean,
): List<ProfileSection> {
    val phoneMissing = phone.isNullOrBlank()
    val account = listOf(
        SettingsRow(icon = Icons.Filled.Person, label = "Personal info", onClick = onOpenPersonalInfo),
        // Phone row always reads "Phone number"; subtitle shows the
        // current number, "Required" pill on the right when missing.
        SettingsRow(
            icon = Icons.Outlined.Phone,
            label = "Phone number",
            chipLabel = if (phoneMissing) "Required" else null,
            chipTone = if (phoneMissing) StatusTone.Warn else StatusTone.Neutral,
            trailing = phone.takeUnless { it.isNullOrBlank() },
            onClick = onOpenAddPhone,
        ),
        // v2.1 PR-C6 — Maintenance contracts (AMC). Visible to both
        // hospital + engineer; the screen itself dispatches the right
        // RPC based on active role.
        SettingsRow(
            icon = Icons.Outlined.CalendarMonth,
            label = "Maintenance contracts",
            onClick = onOpenMaintenanceContracts,
        ),
        SettingsRow(icon = Icons.Outlined.Notifications, label = "Notifications", onClick = onOpenNotifications),
        SettingsRow(icon = Icons.Outlined.Lock, label = "Change password", onClick = onOpenChangePassword),
        SettingsRow(icon = Icons.Outlined.Email, label = "Change email", onClick = onOpenChangeEmail),
    )

    val business = mutableListOf<SettingsRow>().apply {
        if (isEngineer) {
            val (kycLabel, kycTone) = when (engineerStatus) {
                null -> "Start" to StatusTone.Warn
                VerificationStatus.Pending ->
                    if (engineerKycSubmitted) "In review" to StatusTone.Info
                    else "Draft" to StatusTone.Warn
                VerificationStatus.Verified -> "Verified" to StatusTone.Success
                VerificationStatus.Rejected -> "Rejected" to StatusTone.Danger
            }
            add(SettingsRow(
                icon = Icons.Outlined.Shield,
                label = "Verification (KYC)",
                chipLabel = kycLabel,
                chipTone = kycTone,
                onClick = onOpenVerification,
            ))
            add(SettingsRow(
                icon = Icons.Outlined.CurrencyRupee,
                label = "Earnings",
                onClick = onOpenEarnings,
            ))
            add(SettingsRow(icon = Icons.Outlined.AccountBalance, label = "Bank details", onClick = onOpenBankDetails))
        }
        if (isHospital) {
            add(SettingsRow(
                icon = Icons.Outlined.Build,
                label = "My repair jobs",
                onClick = onOpenMyRepairJobs,
            ))
            add(SettingsRow(icon = Icons.Outlined.LocationOn, label = "Addresses", onClick = onOpenAddresses))
            add(SettingsRow(icon = Icons.Outlined.Apartment, label = "Hospital settings", onClick = onOpenHospitalSettings))
            // PR-D41 — hospital self-view of dispute filing history.
            add(SettingsRow(icon = Icons.Outlined.Gavel, label = "Your disputes", onClick = onOpenMyDisputes))
        }
    }

    val support = listOf(
        SettingsRow(
            icon = Icons.AutoMirrored.Outlined.HelpOutline,
            label = "Help & support",
            onClick = onOpenHelp,
        ),
        SettingsRow(icon = Icons.Outlined.Description, label = "About", onClick = onOpenAbout),
        SettingsRow(
            icon = Icons.Outlined.FileUpload,
            label = if (exportingData) "Preparing export…" else "Export my data",
            enabled = !exportingData,
            onClick = onExportData,
        ),
    )

    val danger = listOf(
        SettingsRow(
            icon = Icons.AutoMirrored.Outlined.Logout,
            label = if (signingOut) "Signing out…" else "Sign out",
            danger = true,
            enabled = !signingOut,
            onClick = onSignOut,
        ),
        SettingsRow(
            icon = Icons.Outlined.Close,
            label = if (deletingAccount) "Deleting account…" else "Delete account",
            danger = true,
            enabled = !deletingAccount,
            onClick = onDeleteAccount,
        ),
    )

    val founder = if (isFounder) {
        listOf(
            SettingsRow(
                icon = Icons.Outlined.Shield,
                label = "Founder dashboard",
                onClick = onOpenFounderDashboard,
            ),
        )
    } else emptyList()

    return buildList {
        if (founder.isNotEmpty()) add(ProfileSection("Founder", founder))
        add(ProfileSection("Account", account))
        if (business.isNotEmpty()) add(ProfileSection("Business", business))
        add(ProfileSection("Support", support))
        add(ProfileSection("Danger zone", danger))
    }
}

@Composable
private fun ProfileHero(
    displayName: String,
    email: String?,
    avatarUrl: String?,
    role: UserRole?,
    engineerStatus: VerificationStatus?,
    engineerKycSubmitted: Boolean,
    avatarUploading: Boolean,
    onPickAvatar: () -> Unit,
    onEdit: () -> Unit,
) {
    val initials = displayName
        .split(' ', limit = 2)
        .filter { it.isNotBlank() }
        .map { it.first().uppercaseChar() }
        .joinToString("")
        .ifBlank { "U" }
    val roleLabel = when (role) {
        UserRole.ENGINEER -> "Engineer"
        UserRole.HOSPITAL -> "Hospital admin"
        else -> role?.displayName
    }
    Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(androidx.compose.ui.graphics.Color.White)
                .border(1.dp, com.equipseva.app.designsystem.theme.BorderDefault, RoundedCornerShape(14.dp))
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .clickable(enabled = !avatarUploading, onClick = onPickAvatar),
                contentAlignment = Alignment.Center,
            ) {
                if (!avatarUrl.isNullOrBlank()) {
                    AsyncImage(
                        model = avatarUrl,
                        contentDescription = null,
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape),
                    )
                } else {
                    com.equipseva.app.designsystem.components.Avatar(
                        initials = initials,
                        size = 56.dp,
                        online = com.equipseva.app.designsystem.components.OnlineStatus.Available,
                    )
                }
                if (avatarUploading) {
                    Box(
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape)
                            .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.35f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = androidx.compose.ui.graphics.Color.White,
                        )
                    }
                }
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = displayName,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = com.equipseva.app.designsystem.theme.SevaInk900,
                    maxLines = 1,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                )
                if (!email.isNullOrBlank()) {
                    Text(
                        text = email,
                        fontSize = 12.sp,
                        color = com.equipseva.app.designsystem.theme.SevaInk500,
                        maxLines = 1,
                        overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    )
                }
                if (roleLabel != null) {
                    Spacer(Modifier.height(4.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        com.equipseva.app.designsystem.components.Pill(
                            text = roleLabel,
                            kind = com.equipseva.app.designsystem.components.PillKind.Forest,
                        )
                        if (role == UserRole.ENGINEER) {
                            com.equipseva.app.designsystem.components.KycChip(
                                engineerStatus = engineerStatus,
                                hasDocs = engineerKycSubmitted,
                            )
                        }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(com.equipseva.app.designsystem.theme.Paper2)
                    .clickable(onClick = onEdit)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "Edit",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = com.equipseva.app.designsystem.theme.SevaInk700,
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
private fun SignedOutPrompt(onSignIn: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface50)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(androidx.compose.foundation.shape.CircleShape)
                .background(com.equipseva.app.designsystem.theme.AccentLimeSoft),
            contentAlignment = Alignment.Center,
        ) {
            androidx.compose.material3.Icon(
                imageVector = androidx.compose.material.icons.Icons.Filled.Person,
                contentDescription = null,
                tint = com.equipseva.app.designsystem.theme.BrandGreen,
                modifier = Modifier.size(40.dp),
            )
        }
        Spacer(Modifier.height(Spacing.lg))
        Text(
            "Sign in to continue",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Sign in to buy, list items, contact engineers, and track orders. Browsing stays open without an account.",
            fontSize = 13.sp,
            color = com.equipseva.app.designsystem.theme.Ink500,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.padding(horizontal = Spacing.md),
        )
        Spacer(Modifier.height(Spacing.lg))
        androidx.compose.material3.Button(
            onClick = onSignIn,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Sign in / Sign up", fontWeight = FontWeight.Bold)
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
                // v1 only ships HOSPITAL + ENGINEER hubs. Marketplace roles
                // (SUPPLIER / MANUFACTURER / LOGISTICS) need their own home
                // hubs + dashboards which haven't shipped — switching to one
                // would land the user on an empty / fallback screen. Mirror
                // the gating from RoleSelectScreen: render but disabled with
                // a "Soon" pill.
                val v1Active = role == UserRole.HOSPITAL || role == UserRole.ENGINEER
                RoleOption(
                    role = role,
                    selected = role == selected,
                    current = role == currentRole,
                    enabled = v1Active,
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
                        color = MaterialTheme.colorScheme.onPrimary,
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
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val border = if (selected) {
        BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
    } else {
        BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    }
    OutlinedCard(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.5f),
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
                    } else if (!enabled) {
                        AssistChip(
                            onClick = {},
                            enabled = false,
                            label = { Text("Soon") },
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
    onChangePhone: () -> Unit,
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
                // Same fix as AddPhoneScreen: don't claim SMS verification —
                // we don't run the OTP round-trip in v1. Phone is saved
                // directly to profiles.phone via updateBasicInfo.
                "Phone is managed separately. Tap below to add or change it.",
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
                value = phone.ifBlank { "Not set" },
                onValueChange = {},
                label = { Text("Phone") },
                singleLine = true,
                readOnly = true,
                enabled = false,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedButton(
                onClick = onChangePhone,
                enabled = !saving,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (phone.isBlank()) "Add phone" else "Change phone")
            }
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
                            color = MaterialTheme.colorScheme.onPrimary,
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
