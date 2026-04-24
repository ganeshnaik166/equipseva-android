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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.EquipSevaLogo
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PremiumGradientSurface
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun SignUpScreen(
    onOtpVerifyRequested: (email: String) -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: SignUpViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var tosAccepted by remember { mutableStateOf(false) }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.NavigateToOtpVerify -> onOtpVerifyRequested(effect.email)
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                else -> Unit
            }
        }
    }

    PremiumGradientSurface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.xl, vertical = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            EquipSevaLogo(height = 40.dp, contentDescription = "EquipSeva logo")

            Spacer(Modifier.height(Spacing.lg))

            Text(
                text = "Create your account",
                style = MaterialTheme.typography.displayMedium,
                color = BrandGreenDark,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = "Get access to parts, repair jobs, and UPI billing.",
                style = MaterialTheme.typography.bodyLarge,
                color = Ink500,
            )

            Spacer(Modifier.height(Spacing.sm))

            ErrorBanner(message = state.form.errorMessage)

            EmailField(
                value = state.email,
                onValueChange = viewModel::onEmailChange,
                enabled = !state.form.submitting,
                isError = state.emailError != null,
                errorText = state.emailError,
                imeAction = ImeAction.Done,
                onImeAction = { if (tosAccepted) viewModel.onSubmit() },
            )

            // TOS checkbox row.
            TosCheckboxRow(
                accepted = tosAccepted,
                enabled = !state.form.submitting,
                onToggle = { tosAccepted = !tosAccepted },
            )

            Spacer(Modifier.height(Spacing.xs))

            PrimaryButton(
                label = "Send verification code",
                onClick = viewModel::onSubmit,
                enabled = state.canSubmit && tosAccepted,
                loading = state.form.submitting,
            )

            Spacer(Modifier.height(Spacing.lg))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = "Already have an account? ",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Ink500,
                )
                Text(
                    text = "Sign in",
                    style = MaterialTheme.typography.bodyMedium,
                    color = BrandGreen,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun TosCheckboxRow(
    accepted: Boolean,
    enabled: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onToggle)
            .padding(vertical = Spacing.xs),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(if (accepted) BrandGreen else Color.Transparent)
                .border(
                    width = 2.dp,
                    color = if (accepted) BrandGreen else Surface200,
                    shape = RoundedCornerShape(6.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (accepted) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        Text(
            text = "I accept the Terms of Service and Privacy Policy.",
            style = MaterialTheme.typography.bodyMedium,
            color = Ink700,
        )
    }
}
