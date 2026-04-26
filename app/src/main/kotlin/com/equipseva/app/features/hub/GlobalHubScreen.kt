package com.equipseva.app.features.hub

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import com.equipseva.app.R
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.navigation.Routes

private data class HubService(
    val key: String,
    val title: String,
    val tagline: String,
    val icon: ImageVector,
    val roleKey: String?,        // null = no role grant (founder admin tile)
    val landingRoute: String,    // route to navigate to inside MainNavGraph
)

private val HubServices = listOf(
    HubService(
        key = UserRole.HOSPITAL.storageKey + "_buy_sell",
        title = "Buy / Sell Equipment & Parts",
        tagline = "Browse, list and order — equipment + spare parts",
        icon = Icons.Filled.Storefront,
        roleKey = UserRole.HOSPITAL.storageKey,
        landingRoute = Routes.MARKETPLACE,
    ),
    HubService(
        key = UserRole.HOSPITAL.storageKey + "_book_repair",
        title = "Book Repairmen",
        tagline = "Raise a service request — engineer comes to you",
        icon = Icons.Filled.Build,
        roleKey = UserRole.HOSPITAL.storageKey,
        landingRoute = Routes.REQUEST_SERVICE,
    ),
)

private val AdminTileService = HubService(
    key = HUB_KEY_ADMIN,
    title = "Admin dashboard",
    tagline = "KYC queues, payments, integrity, categories",
    icon = Icons.Filled.AdminPanelSettings,
    roleKey = null,
    landingRoute = Routes.FOUNDER_DASHBOARD,
)

@Composable
fun GlobalHubScreen(
    onAuthRequired: (selectedServiceKey: String, landingRoute: String?) -> Unit,
    onLandOnMain: (landingRoute: String?) -> Unit,
    viewModel: GlobalHubViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is GlobalHubViewModel.Effect.RequireAuth -> onAuthRequired(effect.serviceKey, effect.landingRoute)
                is GlobalHubViewModel.Effect.LandOnMain -> onLandOnMain(effect.landingRoute)
                is GlobalHubViewModel.Effect.ShowMessage -> Unit
            }
        }
    }

    HubContent(
        state = state,
        onSelect = viewModel::onSelect,
        onConfirm = viewModel::confirmAddRole,
        onDismissSheet = viewModel::dismissSheet,
        onSignInTap = {
            onAuthRequired("", null)
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HubContent(
    state: GlobalHubViewModel.UiState,
    onSelect: (serviceKey: String, landingRoute: String?) -> Unit,
    onConfirm: () -> Unit,
    onDismissSheet: () -> Unit,
    onSignInTap: () -> Unit,
) {
    val visibleServices = HubServices + if (state.isFounder) listOf(AdminTileService) else emptyList()
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Surface50,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            HubHero()
            Spacer(Modifier.height(Spacing.lg))
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                visibleServices.forEach { service ->
                    val ownsRole = service.roleKey != null && service.roleKey in state.ownedRoles
                    val isAdmin = service.key == HUB_KEY_ADMIN
                    HubTile(
                        service = service,
                        owned = ownsRole,
                        admin = isAdmin,
                        enabled = !state.acting,
                        onClick = { onSelect(service.key, service.landingRoute) },
                    )
                }
            }
            Spacer(Modifier.height(Spacing.md))
            if (!state.signedIn) {
                SignInRow(onSignInTap = onSignInTap)
                Spacer(Modifier.height(Spacing.lg))
            }
            if (state.error != null) {
                Text(
                    state.error,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                    fontSize = 13.sp,
                )
            }
            Spacer(Modifier.height(Spacing.xl))
        }
    }

    val pending = state.pendingService
    if (pending != null) {
        val service = visibleServices.firstOrNull { it.key == pending }
        val displayTitle = service?.title ?: "service"
        AddServiceSheet(
            serviceTitle = displayTitle,
            tagline = service?.tagline.orEmpty(),
            adding = state.acting,
            onConfirm = onConfirm,
            onDismiss = onDismissSheet,
        )
    }
}

@Composable
private fun HubHero() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    listOf(BrandGreen, BrandGreenDeep),
                ),
            )
            .padding(horizontal = Spacing.lg, vertical = 18.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Image(
                painter = painterResource(id = R.drawable.ic_logo_full),
                contentDescription = "EquipSeva",
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(14.dp)),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Welcome to EquipSeva",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = androidx.compose.ui.graphics.Color.White,
                )
                Text(
                    text = "What would you like to do today?",
                    fontSize = 12.sp,
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                )
            }
        }
    }
}

@Composable
private fun HubTile(
    service: HubService,
    owned: Boolean,
    admin: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = when {
        admin -> AccentLime
        owned -> AccentLime
        else -> Surface200
    }
    val borderWidth = if (admin || owned) 1.5.dp else 1.dp
    val iconBg = if (admin) BrandGreenDeep else AccentLimeSoft
    val iconTint = if (admin) AccentLime else BrandGreen
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Surface0)
            .border(borderWidth, borderColor, RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(iconBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = service.icon,
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(28.dp),
            )
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = service.title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = service.tagline,
                fontSize = 12.sp,
                lineHeight = 15.sp,
                color = Ink500,
            )
        }
        if (admin) {
            HubChip("ADMIN", AccentLime, BrandGreenDeep)
        } else if (owned) {
            HubChip("Added", AccentLimeSoft, BrandGreen)
        } else {
            Text("›", fontSize = 22.sp, color = Ink500)
        }
    }
}

@Composable
private fun HubChip(
    label: String,
    bg: androidx.compose.ui.graphics.Color,
    fg: androidx.compose.ui.graphics.Color,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            label,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            color = fg,
        )
    }
}

@Composable
private fun FounderTile(onClick: () -> Unit) {
    Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(
                    androidx.compose.ui.graphics.Brush.horizontalGradient(
                        listOf(BrandGreen, BrandGreenDeep),
                    ),
                )
                .clickable(onClick = onClick)
                .padding(horizontal = Spacing.md, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AccentLimeSoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.AdminPanelSettings,
                    contentDescription = null,
                    tint = AccentLime,
                    modifier = Modifier.size(20.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Founder dashboard",
                    color = androidx.compose.ui.graphics.Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                Text(
                    "Admin tools, queues, integrity",
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f),
                    fontSize = 11.sp,
                )
            }
        }
    }
}

@Composable
private fun SignInRow(onSignInTap: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Already a member?",
            color = Ink700,
            fontSize = 13.sp,
        )
        TextButton(onClick = onSignInTap) {
            Text(
                "Sign in",
                color = BrandGreen,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddServiceSheet(
    serviceTitle: String,
    tagline: String,
    adding: Boolean,
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
                "Add $serviceTitle to your account?",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            if (tagline.isNotBlank()) {
                Text(
                    tagline,
                    fontSize = 13.sp,
                    color = Ink500,
                )
            }
            Text(
                "You'll be able to switch between services any time from Profile.",
                fontSize = 12.sp,
                color = Ink500,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                OutlinedButton(
                    onClick = onDismiss,
                    enabled = !adding,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = onConfirm,
                    enabled = !adding,
                    colors = ButtonDefaults.buttonColors(containerColor = BrandGreen),
                    modifier = Modifier.weight(1f),
                ) {
                    if (adding) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = androidx.compose.ui.graphics.Color.White,
                        )
                    } else {
                        Text("Add")
                    }
                }
            }
        }
    }
}
