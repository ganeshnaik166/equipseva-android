package com.equipseva.app.features.profile

import com.equipseva.app.R
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
import androidx.compose.material.icons.outlined.CheckCircleOutline
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
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
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.SupportAgent
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.designsystem.components.DeleteAccountSheet
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreen
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
    // round3772 — hospital self-view of loyalty commission tier
    // (v21_commission_tier_loyalty backend, unread by any client
    // until now).
    onOpenCommissionTier: () -> Unit = {},
    // round3775 — engineer self-view of profile completeness meter.
    onOpenProfileCompleteness: () -> Unit = {},
    // round3776 — role-agnostic DPDP grievance filing self-service.
    onOpenDpdpGrievance: () -> Unit = {},
    // round3777 — engineer-to-engineer referral bounty self-service.
    onOpenReferrals: () -> Unit = {},
    // round3778 — hospital account self-service portal.
    onOpenHospitalPortal: () -> Unit = {},
    // round3779 — engineer annual KYC renewal self-service.
    onOpenKycRenewal: () -> Unit = {},
    onSwitchService: () -> Unit = {},
    onSignIn: () -> Unit = {},
    viewModel: ProfileViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current
    // FIX #10 — local Help & Support sheet state. The legacy
    // `onOpenHelp` callback (mailto-direct from MainNavGraph) is
    // overridden below so tapping "Help & support" opens the richer
    // 5-action sheet instead of a bare email composer.
    var helpSheetOpen by androidx.compose.runtime.saveable.rememberSaveable {
        androidx.compose.runtime.mutableStateOf(false)
    }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ProfileViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                is ProfileViewModel.Effect.ShareExport -> shareExportFile(context, effect.path)
                ProfileViewModel.Effect.NavigateHome -> onSwitchService()
            }
        }
    }

    // Re-fetch profile every time we return to this tab (e.g. after
    // AddPhoneScreen pops back) so the "Required" chip on the Phone row
    // and the trailing snapshot text reflect the just-saved value. Skips
    // the very first resume — the init block already loaded the profile.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.onRefresh() }

    Scaffold(
        topBar = {
            EsTopBar(
                title = "Profile",
                right = {
                    // Round 461: 48dp touch min (icon stays 20dp).
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .clickable(
                                onClickLabel = "Open notifications",
                                role = androidx.compose.ui.semantics.Role.Button,
                                onClick = onOpenNotifications,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Notifications,
                            contentDescription = null,
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
                            if (msg != null) stringResource(R.string.profile_load_error_title) else stringResource(R.string.profile_finishing_setup_title),
                            fontWeight = FontWeight.Bold,
                            color = Ink900,
                        )
                        Spacer(Modifier.height(Spacing.sm))
                        Text(
                            msg ?: stringResource(R.string.profile_loading_fallback_body),
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
                            Text(stringResource(R.string.common_retry))
                        }
                    }
                }
                else -> {
                    ProfileContent(
                        state = state,
                        onEditRole = viewModel::onOpenRoleEditor,
                        onSignOut = viewModel::onOpenSignOutConfirm,
                        onEditProfile = viewModel::onOpenEditProfile,
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
                        // FIX #10 — route through the local sheet
                        // instead of MainNavGraph's mailto-direct.
                        onOpenHelp = { helpSheetOpen = true },
                        onOpenPublicPreview = onOpenPublicPreview,
                        onOpenMaintenanceContracts = onOpenMaintenanceContracts,
                        onOpenMyDisputes = onOpenMyDisputes,
                        onOpenCommissionTier = onOpenCommissionTier,
                        onOpenProfileCompleteness = onOpenProfileCompleteness,
                        onOpenDpdpGrievance = onOpenDpdpGrievance,
                        onOpenReferrals = onOpenReferrals,
                        onOpenHospitalPortal = onOpenHospitalPortal,
                        onOpenKycRenewal = onOpenKycRenewal,
                        onSwitchService = viewModel::onToggleRoleAndGoHome,
                        onPickAvatar = viewModel::uploadAvatar,
                    )
                }
            }
        }
    }

    // FIX #10 — Help & Support escalation sheet. Hospital surfaces the
    // same 5-action sheet here (Profile > Account > Help & support)
    // that it does on Home and RepairJobDetail. Replaces the legacy
    // bare-mailto path that gave the user no menu of options.
    if (helpSheetOpen) {
        com.equipseva.app.designsystem.components.HelpSupportSheet(
            onClose = { helpSheetOpen = false },
            onShowMessage = onShowMessage,
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
            title = { androidx.compose.material3.Text(stringResource(R.string.profile_export_confirm_title)) },
            text = {
                androidx.compose.material3.Text(
                    stringResource(R.string.profile_export_confirm_body),
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = viewModel::onExportMyData) {
                    androidx.compose.material3.Text(stringResource(R.string.profile_export_confirm_action))
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = viewModel::onDismissExportConfirm) {
                    androidx.compose.material3.Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }

    if (state.signOutConfirmOpen) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = viewModel::onDismissSignOutConfirm,
            title = { androidx.compose.material3.Text(stringResource(R.string.profile_signout_confirm_title)) },
            text = {
                androidx.compose.material3.Text(
                    stringResource(R.string.profile_signout_confirm_body),
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(
                    onClick = viewModel::onSignOut,
                    enabled = !state.signingOut,
                ) {
                    androidx.compose.material3.Text(
                        if (state.signingOut) stringResource(R.string.profile_signout_in_progress_label) else stringResource(R.string.profile_signout_action_label),
                        color = ErrorRed,
                    )
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(
                    onClick = viewModel::onDismissSignOutConfirm,
                    enabled = !state.signingOut,
                ) { androidx.compose.material3.Text(stringResource(R.string.profile_signout_stay_action)) }
            },
        )
    }

    if (state.deleteAccountOpen) {
        DeleteAccountSheet(
            reason = state.deleteReason,
            password = state.deletePassword,
            passwordError = state.deletePasswordError,
            deleting = state.deletingAccount,
            onReasonChange = viewModel::onDeleteReasonChange,
            onPasswordChange = viewModel::onDeletePasswordChange,
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
    onEditRole: () -> Unit,
    onSignOut: () -> Unit,
    onEditProfile: () -> Unit,
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
    onOpenCommissionTier: () -> Unit,
    onOpenProfileCompleteness: () -> Unit,
    onOpenDpdpGrievance: () -> Unit,
    onOpenReferrals: () -> Unit,
    onOpenHospitalPortal: () -> Unit,
    onOpenKycRenewal: () -> Unit,
    onSwitchService: () -> Unit,
    onPickAvatar: (Uri) -> Unit,
) {
    val profile = state.profile!!
    // Multi-role accounts hold every role they've ever opted into in
    // `profile.role` (the scalar), while `profile.activeRole` is the
    // role surfaced by the bottom-tab Hub. Reading `role` here let a
    // hospital admin who'd been auto-seeded as ENGINEER (default on
    // signup before the role-tile flip) see engineer-only sections —
    // KYC, Earnings, Bank details — on their Profile while the rest of
    // the app correctly rendered the hospital home. Prefer activeRole
    // and fall back to the scalar so single-role accounts behave the
    // same as before.
    val displayedRole = profile.activeRole ?: profile.role
    val isEngineer = displayedRole == UserRole.ENGINEER
    val isHospital = displayedRole == UserRole.HOSPITAL
    val isSupplier = displayedRole == UserRole.SUPPLIER
    val isManufacturer = displayedRole == UserRole.MANUFACTURER
    val isLogistics = displayedRole == UserRole.LOGISTICS
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
            // Mirror PR #650 — the hero pill + KYC chip key off the
            // role passed in, so use displayedRole instead of the
            // scalar so a hospital admin auto-seeded as ENGINEER
            // doesn't see an engineer pill + "Start" KYC chip on the
            // hero while the rest of Profile renders hospital.
            role = displayedRole,
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
            activeRoleLabel = profile.role?.displayName ?: "Not set",
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
            onOpenCommissionTier = onOpenCommissionTier,
            onOpenProfileCompleteness = onOpenProfileCompleteness,
            onOpenDpdpGrievance = onOpenDpdpGrievance,
            onOpenReferrals = onOpenReferrals,
            onOpenHospitalPortal = onOpenHospitalPortal,
            onOpenKycRenewal = onOpenKycRenewal,
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
                // Use displayedRole (activeRole ?: scalar), NOT the raw
                // profile.role scalar — same auto-seed correction the hero
                // pill + section gating already use above. A hospital admin
                // auto-seeded as ENGINEER was seeing "Account type: Biomedical
                // engineer / You bid on and complete repair jobs" here while
                // the hero pill (also displayedRole) correctly said "Hospital
                // admin". The comment on ProfileHero notes the two are meant
                // to match. (Found on-device, r1456.)
                AccountTypeSection(role = displayedRole, onEditRole = onEditRole)
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
                text = stringResource(R.string.profile_suspension_title),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = com.equipseva.app.designsystem.theme.SevaDanger500,
            )
        }
        Text(
            text = engineerSuspensionReason(suspension.reason, suspension.flagCount90d),
            fontSize = 12.sp,
            color = com.equipseva.app.designsystem.theme.SevaInk700,
        )
        suspension.suspendedAt?.let {
            Text(
                text = stringResource(R.string.profile_suspension_paused_at, formatSuspensionTimestamp(it)),
                fontSize = 11.sp,
                color = com.equipseva.app.designsystem.theme.SevaInk500,
            )
        }
        Text(
            text = stringResource(R.string.profile_suspension_support_note),
            fontSize = 12.sp,
            color = com.equipseva.app.designsystem.theme.SevaInk700,
        )
    }
}

@Composable
private fun AccountTypeSection(role: UserRole?, onEditRole: () -> Unit) {
    val (title, subtitle) = accountTypeSectionCopy(role)
    Text(
        text = stringResource(R.string.profile_account_type_title),
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
    activeRoleLabel: String,
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
    onOpenCommissionTier: () -> Unit,
    onOpenProfileCompleteness: () -> Unit,
    onOpenDpdpGrievance: () -> Unit,
    onOpenReferrals: () -> Unit,
    onOpenHospitalPortal: () -> Unit,
    onOpenKycRenewal: () -> Unit,
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
        // round3776 — DPDP grievance filing self-service (round485
        // backend, unread by any client until now). Role-agnostic:
        // DPDP treats every account holder as a data principal
        // regardless of marketplace role.
        SettingsRow(
            icon = Icons.Outlined.Shield,
            label = "Privacy & data rights",
            onClick = onOpenDpdpGrievance,
        ),
    )

    val business = mutableListOf<SettingsRow>().apply {
        if (isEngineer) {
            val (kycLabel, kycTone) = kycRowLabelAndTone(engineerStatus, engineerKycSubmitted)
            add(SettingsRow(
                icon = Icons.Outlined.Shield,
                label = "Verification (KYC)",
                chipLabel = kycLabel,
                chipTone = kycTone,
                onClick = onOpenVerification,
            ))
            // round3779 — annual KYC renewal self-service (round497
            // backend, unread by any client until now). Only relevant
            // to already-verified engineers; a not-yet-verified
            // engineer has no renewal row (my_kyc_renewal returns
            // none), so this stays visible but shows an empty state
            // for them rather than being hidden conditionally.
            add(SettingsRow(
                icon = Icons.Outlined.Shield,
                label = "KYC renewal",
                onClick = onOpenKycRenewal,
            ))
            add(SettingsRow(
                icon = Icons.Outlined.CurrencyRupee,
                label = "Earnings",
                onClick = onOpenEarnings,
            ))
            add(SettingsRow(icon = Icons.Outlined.AccountBalance, label = "Payout method", onClick = onOpenBankDetails))
            // round3775 — profile completeness meter (round504 backend,
            // unread by any client until now).
            add(SettingsRow(
                icon = Icons.Outlined.CheckCircleOutline,
                label = "Profile completeness",
                onClick = onOpenProfileCompleteness,
            ))
            // round3777 — engineer-to-engineer referral bounty (round564
            // + round568 security patch, unread by any client until now).
            add(SettingsRow(
                icon = Icons.Filled.Star,
                label = "Refer an engineer",
                onClick = onOpenReferrals,
            ))
            // Engineers want to see how hospitals see them — the public-
            // preview lambda was already plumbed from MainNavGraph but
            // never wired to a row. Only show when verified + we have
            // their engineer id to feed into the public profile route.
            if (engineerStatus == VerificationStatus.Verified && !ownEngineerId.isNullOrBlank()) {
                add(SettingsRow(
                    icon = Icons.Outlined.Visibility,
                    label = "Preview public profile",
                    onClick = { onOpenPublicPreview(ownEngineerId) },
                ))
            }
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
            // round3778 — Hospital Portal v2 self-service (round1395
            // backend, unread by any client until now).
            add(SettingsRow(
                icon = Icons.Outlined.SupportAgent,
                label = "Account self-service",
                onClick = onOpenHospitalPortal,
            ))
            // round3772 — loyalty commission tier self-view (v21
            // get_my_commission_tier backend, unread by any client
            // until now).
            add(SettingsRow(
                icon = Icons.Outlined.TrendingUp,
                label = "Commission tier",
                onClick = onOpenCommissionTier,
            ))
            // Messages row removed (v0.3.4) — now a hospital bottom-nav tab.
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

/**
 * Verification-row label + tone shown next to "Verification (KYC)" on
 * the engineer Profile. The four-way map encodes the canonical KYC
 * lifecycle, with the extra Draft-vs-In-review distinction for
 * Pending: server-side the engineer is in a single "pending" bucket,
 * but the client splits it so the row reflects whether the engineer
 * has actually finished uploading the three required docs.
 */
internal fun kycRowLabelAndTone(
    engineerStatus: VerificationStatus?,
    engineerKycSubmitted: Boolean,
): Pair<String, StatusTone> = when (engineerStatus) {
    null -> "Start" to StatusTone.Warn
    VerificationStatus.Pending ->
        if (engineerKycSubmitted) "In review" to StatusTone.Info
        else "Draft" to StatusTone.Warn
    VerificationStatus.Verified -> "Verified" to StatusTone.Success
    VerificationStatus.Rejected -> "Rejected" to StatusTone.Danger
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
    val initials = profileHeroInitials(displayName)
    // Use UserRole.displayName so the Profile hero pill matches the
    // AccountTypeSection title + role-editor sheet ("Hospital admin",
    // "Biomedical engineer"). Round 12 unified the rest; the hero
    // pill was the last surface still rendering "Engineer" instead.
    val roleLabel = role?.displayName
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
                        // Non-square sources (e.g. a tall portrait the
                        // user uploaded) would otherwise letterbox inside
                        // the 56dp circle, wasting decoded-Bitmap memory
                        // and showing a thin ring of background. Crop
                        // fills the circle while Coil scales down to fit.
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape),
                    )
                } else {
                    com.equipseva.app.designsystem.components.Avatar(
                        initials = initials,
                        size = 56.dp,
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
                    text = stringResource(R.string.address_book_edit_action),
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
            stringResource(R.string.profile_signed_out_title),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.profile_signed_out_body),
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
            Text(stringResource(R.string.profile_signed_out_cta), fontWeight = FontWeight.Bold)
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
                stringResource(R.string.profile_role_editor_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                stringResource(R.string.profile_role_editor_subtitle),
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
                val v1Active = isV1ActiveRole(role)
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
                    Text(stringResource(R.string.profile_action_saving))
                } else {
                    Text(stringResource(R.string.common_save))
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
                            label = { Text(stringResource(R.string.profile_role_current_chip)) },
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
                            label = { Text(stringResource(R.string.profile_role_soon_chip)) },
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
                stringResource(R.string.profile_edit_sheet_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                // Same fix as AddPhoneScreen: don't claim SMS verification —
                // we don't run the OTP round-trip in v1. Phone is saved
                // directly to profiles.phone via updateBasicInfo.
                stringResource(R.string.profile_edit_sheet_phone_note),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            HorizontalDivider()
            OutlinedTextField(
                value = fullName,
                onValueChange = onFullNameChange,
                label = { Text(stringResource(R.string.profile_edit_sheet_fullname_label)) },
                singleLine = true,
                enabled = !saving,
                // Full name is a proper noun — capitalize each word
                // on the soft keyboard. Without this, the user has
                // to manually shift each first letter, which is the
                // most common typo path in India where most names
                // are 2-3 capitalized words.
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = phone.ifBlank { "Not set" },
                onValueChange = {},
                label = { Text(stringResource(R.string.engineer_onboarding_phone_label)) },
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
                Text(if (phone.isBlank()) stringResource(R.string.profile_edit_sheet_add_phone_action) else stringResource(R.string.profile_edit_sheet_change_phone_action))
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
                ) { Text(stringResource(R.string.common_cancel)) }
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
                        Text(stringResource(R.string.profile_action_saving))
                    } else {
                        Text(stringResource(R.string.common_save))
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

/**
 * User-facing reason copy on the engineer-suspension banner.
 * Server-provided [explicitReason] wins; otherwise compose a generic
 * line referencing the flag count in the last 90 days.
 *
 * Singular/plural split: 1 flag → "1 hospital cash-payment flag",
 * 2+ → "N hospital cash-payment flags". Pin so a regression to
 * always-interpolated count doesn't surface "1 flags" on the most
 * common one-strike case.
 */
internal fun engineerSuspensionReason(explicitReason: String?, flagCount90d: Int): String {
    if (explicitReason != null) return explicitReason
    val flagPhrase = if (flagCount90d == 1) {
        "1 hospital cash-payment flag"
    } else {
        "$flagCount90d hospital cash-payment flags"
    }
    return "$flagPhrase in the last 90 days. EquipSeva paused your availability while we review."
}

/**
 * Trim an ISO-8601 timestamp to "YYYY-MM-DD HH:MM:SS" for the
 * "Paused: …" line on the suspension banner. Replaces the ISO 'T'
 * separator with a space so the line reads naturally rather than
 * forcing a context switch back to machine-readable shape.
 *
 * Inputs shorter than 19 chars take whatever's there (defensive —
 * a server-side rename to a shorter format would still render).
 */
internal fun formatSuspensionTimestamp(iso: String): String =
    iso.take(19).replace('T', ' ')

/**
 * Account-type section copy on the Profile screen. Role can legitimately
 * be null while the profile is mid-fetch — render a neutral "Loading…"
 * title in that case, NOT a misleading "Hospital admin" fallback (a
 * previous regression collapsed null + ENGINEER-not-equal into the same
 * branch). Per-role title comes from [UserRole.displayName] so the
 * role-editor sheet + snackbar + this section all stay in sync.
 *
 * Engineer/Hospital get hand-written first-person subtitles ("You bid
 * on…", "You book…"); other roles fall back to [UserRole.description].
 */
internal fun accountTypeSectionCopy(role: UserRole?): Pair<String, String> {
    val title = role?.displayName ?: "Loading…"
    val subtitle = when (role) {
        UserRole.ENGINEER -> "You bid on and complete repair jobs"
        UserRole.HOSPITAL -> "You book engineers for repairs"
        null -> ""
        else -> role.description
    }
    return title to subtitle
}

/**
 * Initials shown on the Profile hero avatar.
 *
 * Distinct from [com.equipseva.app.core.util.initialsOf]:
 *   - This helper uses "U" as the fallback (for "User"); initialsOf
 *     uses "?". The Profile hero is the user's OWN screen — "U" is
 *     a sensible default for an unnamed self-record. "?" would read
 *     as "we don't know who you are", which is wrong.
 *   - This helper uses Char-split + first(); initialsOf uses String-
 *     split + firstOrNull(). Behaviour is equivalent (filter +
 *     isNotBlank guards the first() call).
 *
 * Pin both deviations so a refactor that "unified" with initialsOf
 * (changing the fallback or trimming behaviour) doesn't slip in.
 */
internal fun profileHeroInitials(displayName: String): String =
    displayName
        .split(' ', limit = 2)
        .filter { it.isNotBlank() }
        .map { it.first().uppercaseChar() }
        .joinToString("")
        .ifBlank { "U" }

/**
 * v1 launch gating — true when the role has a shipped Home hub.
 *
 * HOSPITAL + ENGINEER ship with full hubs in v1. SUPPLIER /
 * MANUFACTURER / LOGISTICS are marketplace roles that need their own
 * home hubs + dashboards which haven't shipped — switching to one
 * would land the user on an empty / fallback screen.
 *
 * Pin so a refactor that flipped any of the marketplace roles to
 * `true` without shipping the hub would surface here as a deliberate
 * change.
 */
internal fun isV1ActiveRole(role: UserRole): Boolean =
    role == UserRole.HOSPITAL || role == UserRole.ENGINEER
