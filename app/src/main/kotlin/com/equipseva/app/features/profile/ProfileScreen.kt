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
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Receipt
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.core.util.AppFeatureFlags
import com.equipseva.app.designsystem.components.BrandedPlaceholder
import com.equipseva.app.designsystem.components.DeleteAccountSheet
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SettingsSheet
import com.equipseva.app.designsystem.components.StatusChip
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
    onOpenFavorites: () -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    onOpenBankDetails: () -> Unit = {},
    onOpenAddresses: () -> Unit = {},
    onOpenHospitalSettings: () -> Unit = {},
    onOpenFounderDashboard: () -> Unit = {},
    onOpenChangePassword: () -> Unit = {},
    onOpenChangeEmail: () -> Unit = {},
    onOpenOrders: () -> Unit = {},
    onOpenSellerVerification: () -> Unit = {},
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
                    // PRD: signed-out users can browse Marketplace freely. The
                    // Profile tab now shows a sign-in CTA instead of an error,
                    // so a tap from the bottom nav doesn't look broken.
                    SignedOutPrompt(onSignIn = onSignIn)
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
                        onOpenBankDetails = onOpenBankDetails,
                        onOpenAddresses = onOpenAddresses,
                        onOpenHospitalSettings = onOpenHospitalSettings,
                        onOpenFounderDashboard = onOpenFounderDashboard,
                        onDeleteAccount = viewModel::onOpenDeleteAccount,
                        onExportData = viewModel::onExportMyData,
                        onOpenChangePassword = onOpenChangePassword,
                        onOpenChangeEmail = onOpenChangeEmail,
                        onOpenOrders = onOpenOrders,
                        onOpenSellerVerification = onOpenSellerVerification,
                        onSwitchService = onSwitchService,
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
    onOpenBankDetails: () -> Unit,
    onOpenAddresses: () -> Unit,
    onOpenHospitalSettings: () -> Unit,
    onOpenFounderDashboard: () -> Unit,
    onDeleteAccount: () -> Unit,
    onExportData: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
    onOpenOrders: () -> Unit,
    onOpenSellerVerification: () -> Unit,
    onSwitchService: () -> Unit,
) {
    val profile = state.profile!!
    val isEngineer = profile.role == UserRole.ENGINEER
    val isHospital = profile.role == UserRole.HOSPITAL
    val isSupplier = profile.role == UserRole.SUPPLIER
    val isManufacturer = profile.role == UserRole.MANUFACTURER
    val isLogistics = profile.role == UserRole.LOGISTICS
    val isFounder = profile.isFounder()

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
            verified = profile.roleConfirmed,
            isFounder = isFounder,
            organizationName = profile.organizationName,
            locationLine = profile.locationLine,
            onEdit = onEditProfile,
            onChangeRole = onEditRole,
            roleUpdating = state.roleUpdating,
        )

        if (isFounder) {
            Spacer(Modifier.height(Spacing.md))
            FounderCallout(onClick = onOpenFounderDashboard)
        }

        Spacer(Modifier.height(Spacing.md))

        val sections = buildProfileSections(
            isEngineer = isEngineer,
            isHospital = isHospital,
            isSupplier = isSupplier,
            isManufacturer = isManufacturer,
            isLogistics = isLogistics,
            themeMode = themeMode,
            activeRoleLabel = profile.role?.displayName ?: "Not set",
            onOpenSettings = onOpenSettings,
            onOpenVerification = onOpenVerification,
            onOpenMessages = onOpenMessages,
            onOpenAbout = onOpenAbout,
            onOpenFavorites = onOpenFavorites,
            onOpenNotifications = onOpenNotifications,
            onOpenPersonalInfo = onEditProfile,
            onOpenBankDetails = onOpenBankDetails,
            onOpenAddresses = onOpenAddresses,
            onOpenHospitalSettings = onOpenHospitalSettings,
            onOpenChangePassword = onOpenChangePassword,
            onOpenChangeEmail = onOpenChangeEmail,
            onOpenOrders = onOpenOrders,
            onOpenSellerVerification = onOpenSellerVerification,
            onSwitchService = onSwitchService,
            onSignOut = onSignOut,
            signingOut = state.signingOut,
            onDeleteAccount = onDeleteAccount,
            deletingAccount = state.deletingAccount,
            onExportData = onExportData,
            exportingData = state.exportingData,
        )

        sections.forEachIndexed { index, section ->
            ProfileSectionView(section)
            if (index < sections.size - 1) Spacer(Modifier.height(Spacing.lg))
        }

        Spacer(Modifier.height(Spacing.xl))
    }
}

private data class ProfileSection(
    val title: String,
    val rows: List<SettingsRow>,
)

@Composable
private fun ProfileSectionView(section: ProfileSection) {
    Column(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Text(
            section.title.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink500,
            letterSpacing = 0.6.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
        )
        SettingsList(rows = section.rows)
    }
}

@Composable
private fun FounderCallout(onClick: () -> Unit) {
    Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(
                    androidx.compose.ui.graphics.Brush.horizontalGradient(
                        listOf(BrandGreen, BrandGreenDark),
                    ),
                )
                .clickable(onClick = onClick)
                .padding(horizontal = Spacing.lg, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.AdminPanelSettings,
                    contentDescription = null,
                    tint = androidx.compose.ui.graphics.Color.White,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Founder dashboard",
                    color = androidx.compose.ui.graphics.Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                )
                Text(
                    "KYC, reports, users, payments",
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                    fontSize = 12.sp,
                )
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = androidx.compose.ui.graphics.Color.White,
            )
        }
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
    themeMode: ThemeMode,
    activeRoleLabel: String,
    onOpenSettings: () -> Unit,
    onOpenVerification: () -> Unit,
    onOpenMessages: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenNotifications: () -> Unit,
    onOpenPersonalInfo: () -> Unit,
    onOpenBankDetails: () -> Unit,
    onOpenAddresses: () -> Unit,
    onOpenHospitalSettings: () -> Unit,
    onOpenChangePassword: () -> Unit,
    onOpenChangeEmail: () -> Unit,
    onOpenOrders: () -> Unit,
    onOpenSellerVerification: () -> Unit,
    onSwitchService: () -> Unit,
    onSignOut: () -> Unit,
    signingOut: Boolean,
    onDeleteAccount: () -> Unit,
    deletingAccount: Boolean,
    onExportData: () -> Unit,
    exportingData: Boolean,
): List<ProfileSection> {
    val account = listOfNotNull(
        SettingsRow(icon = Icons.Filled.Person, label = "Personal info", onClick = onOpenPersonalInfo),
        // Marketplace v1 gate: My orders points at the marketplace order
        // history. Hidden in v1; v2 brings it back when MARKETPLACE_ENABLED.
        if (AppFeatureFlags.MARKETPLACE_ENABLED)
            SettingsRow(icon = Icons.Filled.Receipt, label = "My orders", onClick = onOpenOrders)
        else null,
        SettingsRow(icon = Icons.Outlined.Notifications, label = "Notifications", onClick = onOpenNotifications),
        SettingsRow(icon = Icons.Outlined.Lock, label = "Change password", onClick = onOpenChangePassword),
        SettingsRow(icon = Icons.Outlined.Email, label = "Change email", onClick = onOpenChangeEmail),
        SettingsRow(
            icon = Icons.Outlined.Palette,
            label = "Appearance",
            trailing = themeMode.displayLabel(),
            onClick = onOpenSettings,
        ),
    )

    val business = mutableListOf<SettingsRow>().apply {
        if (isEngineer) {
            add(SettingsRow(
                icon = Icons.Outlined.VerifiedUser,
                label = "Verification (KYC)",
                chipLabel = "Review",
                chipTone = StatusTone.Warn,
                onClick = onOpenVerification,
            ))
            add(SettingsRow(icon = Icons.Filled.AccountBalance, label = "Bank details", onClick = onOpenBankDetails))
        }
        if (isHospital) {
            add(SettingsRow(icon = Icons.Filled.LocationOn, label = "Addresses", onClick = onOpenAddresses))
            add(SettingsRow(icon = Icons.Filled.LocalHospital, label = "Hospital settings", onClick = onOpenHospitalSettings))
        }
        // Marketplace v1 gate: supplier + manufacturer business rows are
        // all seller-side surfaces. Skip them entirely until v2.
        if (AppFeatureFlags.MARKETPLACE_ENABLED && isSupplier) {
            add(SettingsRow(
                icon = Icons.Outlined.VerifiedUser,
                label = "Seller verification",
                chipLabel = "GST + licence",
                chipTone = StatusTone.Warn,
                onClick = onOpenSellerVerification,
            ))
            add(SettingsRow(icon = Icons.Filled.Storefront, label = "Storefront", onClick = onOpenHospitalSettings))
            add(SettingsRow(icon = Icons.Filled.AccountBalance, label = "Bank details", onClick = onOpenBankDetails))
        }
        if (AppFeatureFlags.MARKETPLACE_ENABLED && isManufacturer) {
            add(SettingsRow(
                icon = Icons.Outlined.VerifiedUser,
                label = "Seller verification",
                chipLabel = "GST + licence",
                chipTone = StatusTone.Warn,
                onClick = onOpenSellerVerification,
            ))
            add(SettingsRow(icon = Icons.Filled.Factory, label = "Brand portfolio", onClick = onOpenHospitalSettings))
            add(SettingsRow(icon = Icons.Filled.AccountBalance, label = "Bank details", onClick = onOpenBankDetails))
        }
        if (isLogistics) {
            add(SettingsRow(icon = Icons.Filled.LocalShipping, label = "Vehicle details", onClick = onOpenHospitalSettings))
            add(SettingsRow(icon = Icons.Filled.AccountBalance, label = "Bank details", onClick = onOpenBankDetails))
        }
    }

    val support = listOf(
        SettingsRow(icon = Icons.Outlined.Info, label = "About", onClick = onOpenAbout),
        SettingsRow(
            icon = Icons.Filled.CloudDownload,
            label = if (exportingData) "Preparing export…" else "Export my data",
            enabled = !exportingData,
            onClick = onExportData,
        ),
    )

    val danger = listOf(
        SettingsRow(
            icon = Icons.AutoMirrored.Filled.Logout,
            label = if (signingOut) "Signing out…" else "Sign out",
            danger = true,
            enabled = !signingOut,
            onClick = onSignOut,
        ),
        SettingsRow(
            icon = Icons.Filled.DeleteForever,
            label = if (deletingAccount) "Deleting account…" else "Delete account",
            danger = true,
            enabled = !deletingAccount,
            onClick = onDeleteAccount,
        ),
    )

    return buildList {
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
    verified: Boolean,
    isFounder: Boolean,
    organizationName: String?,
    locationLine: String?,
    onEdit: () -> Unit,
    onChangeRole: () -> Unit,
    roleUpdating: Boolean,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    listOf(BrandGreen, BrandGreenDark),
                ),
            )
            .padding(horizontal = Spacing.lg, vertical = 22.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(40.dp)
                .clip(CircleShape)
                .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.18f))
                .clickable(onClick = onEdit),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Edit,
                contentDescription = "Edit profile",
                tint = androidx.compose.ui.graphics.Color.White,
                modifier = Modifier.size(20.dp),
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.18f))
                        .border(2.dp, androidx.compose.ui.graphics.Color.White.copy(alpha = 0.5f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (!avatarUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = avatarUrl,
                            contentDescription = null,
                            modifier = Modifier
                                .size(72.dp)
                                .clip(CircleShape),
                        )
                    } else {
                        Text(
                            text = displayName.firstOrNull()?.uppercaseChar()?.toString() ?: "U",
                            color = androidx.compose.ui.graphics.Color.White,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = displayName,
                        color = androidx.compose.ui.graphics.Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    if (!email.isNullOrBlank()) {
                        Text(
                            text = email,
                            color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                            fontSize = 13.sp,
                        )
                    }
                    val secondary = listOfNotNull(
                        organizationName?.takeIf { it.isNotBlank() },
                        locationLine?.takeIf { it.isNotBlank() },
                    ).joinToString(" · ")
                    if (secondary.isNotBlank()) {
                        Text(
                            text = secondary,
                            color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.75f),
                            fontSize = 12.sp,
                        )
                    }
                }
            }

            // v1: no role chip / no role-change UI in Profile. The 3-card
            // Home picks the user's intent each session; the role concept
            // stays server-side for RLS but is hidden from the client.
            if (isFounder) {
                Spacer(Modifier.height(2.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    HeroChip(
                        label = "Founder",
                        icon = Icons.Filled.AdminPanelSettings,
                    )
                }
            }
        }
    }
}

@Composable
private fun HeroChip(label: String, icon: ImageVector) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.18f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = androidx.compose.ui.graphics.Color.White,
            modifier = Modifier.size(14.dp),
        )
        Text(
            label,
            color = androidx.compose.ui.graphics.Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
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
