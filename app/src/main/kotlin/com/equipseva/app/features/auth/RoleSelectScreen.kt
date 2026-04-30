package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.auth.state.AuthEffect

private data class RoleVisual(
    val icon: ImageVector,
    val label: String,
    val desc: String,
    val active: Boolean,
)

private fun UserRole.visual(): RoleVisual = when (this) {
    UserRole.HOSPITAL -> RoleVisual(
        Icons.Filled.Apartment,
        "Hospital admin",
        "Book engineers for your facility",
        true,
    )
    UserRole.ENGINEER -> RoleVisual(
        Icons.Filled.Build,
        "Engineer",
        "Independent biomedical technician",
        true,
    )
    UserRole.SUPPLIER -> RoleVisual(
        Icons.Filled.Inventory2,
        "Supplier",
        "Coming soon",
        false,
    )
    UserRole.MANUFACTURER -> RoleVisual(
        Icons.Filled.Layers,
        "Manufacturer",
        "Coming soon",
        false,
    )
    UserRole.LOGISTICS -> RoleVisual(
        Icons.Filled.LocalShipping,
        "Logistics",
        "Coming soon",
        false,
    )
}

@Composable
fun RoleSelectScreen(
    onShowMessage: (String) -> Unit,
    onBack: () -> Unit = {},
    viewModel: RoleSelectViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                AuthEffect.NavigateToHome -> Unit
                else -> Unit
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars),
        ) {
            EsTopBar(title = "Pick your role", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = "You can switch later from your profile.",
                    style = EsType.BodySm,
                    color = SevaInk600,
                    modifier = Modifier.padding(bottom = 10.dp),
                )

                ErrorBanner(message = state.form.errorMessage)

                state.roles.forEach { role ->
                    RoleCard(
                        role = role,
                        selected = role == state.selected,
                        onClick = { viewModel.onRoleSelected(role) },
                    )
                }
            }
            // Bottom action bar
            Surface(color = Color.White, shadowElevation = 0.dp) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(0.dp))
                        .padding(20.dp),
                ) {
                    EsBtn(
                        text = "Continue",
                        onClick = viewModel::onConfirm,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = !state.canConfirm,
                    )
                }
            }
        }
    }
}

@Composable
private fun RoleCard(
    role: UserRole,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val v = role.visual()
    val borderColor = if (selected) SevaGreen700 else BorderDefault
    val bg = if (selected) SevaGreen50 else Color.White
    val tileBg = if (selected) SevaGreen700 else Paper2
    val tileFg = if (selected) Color.White else SevaInk600
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .border(1.5.dp, borderColor, RoundedCornerShape(12.dp))
            .alpha(if (v.active) 1f else 0.5f)
            .let { if (v.active) it.clickable(onClick = onClick) else it }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(tileBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = v.icon,
                contentDescription = "${v.label} role icon",
                tint = tileFg,
                modifier = Modifier.size(20.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = v.label,
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = v.desc,
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
        if (!v.active) {
            Pill(text = "Soon", kind = PillKind.Default)
        } else if (selected) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = "Selected",
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        } else {
            Box(modifier = Modifier.size(20.dp))
        }
    }
}
