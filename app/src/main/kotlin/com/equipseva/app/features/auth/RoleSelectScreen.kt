package com.equipseva.app.features.auth

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.AuthScaffold
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink400
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun RoleSelectScreen(
    onShowMessage: (String) -> Unit,
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

    AuthScaffold(
        title = "How will you use EquipSeva?",
        subtitle = "Pick the role that fits you best. You can change this later in Profile.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        state.roles.forEach { role ->
            RoleCard(
                role = role,
                selected = role == state.selected,
                onClick = { viewModel.onRoleSelected(role) },
            )
        }

        Spacer(Modifier.height(Spacing.md))

        PrimaryButton(
            label = "Continue",
            onClick = viewModel::onConfirm,
            enabled = state.canConfirm,
            loading = state.form.submitting,
        )
    }
}

private data class RoleVisual(val icon: ImageVector, val hue: Int)

private fun UserRole.visual(): RoleVisual = when (this) {
    UserRole.HOSPITAL -> RoleVisual(Icons.Filled.LocalHospital, 200)
    UserRole.ENGINEER -> RoleVisual(Icons.Filled.Build, 150)
    UserRole.SUPPLIER -> RoleVisual(Icons.Filled.Store, 40)
    UserRole.MANUFACTURER -> RoleVisual(Icons.Filled.Factory, 280)
    UserRole.LOGISTICS -> RoleVisual(Icons.Filled.LocalShipping, 330)
}

@Composable
private fun RoleCard(
    role: UserRole,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val visual = role.visual()
    val border = if (selected) {
        BorderStroke(2.dp, BrandGreen)
    } else {
        BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    }
    OutlinedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(5.dp),
        border = border,
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GradientTile(
                icon = visual.icon,
                hue = visual.hue,
                size = 48.dp,
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = role.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                Text(
                    text = role.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
            SelectionMark(selected = selected)
        }
    }
}

@Composable
private fun SelectionMark(selected: Boolean) {
    if (selected) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(BrandGreen, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = "Selected",
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
        }
    } else {
        Box(
            modifier = Modifier
                .size(20.dp)
                .border(2.dp, Ink400, CircleShape),
        )
    }
}
