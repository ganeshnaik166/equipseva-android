package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.AuthScaffold
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.components.SocialButton
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
    onUseEmailCode: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: WelcomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                AuthEffect.NavigateToHome -> Unit // SessionViewModel will route us out automatically.
                else -> Unit
            }
        }
    }

    AuthScaffold(
        title = "Welcome to EquipSeva",
        subtitle = "Buy medical parts, request repairs, manage your equipment — all in one place.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        Spacer(Modifier.height(Spacing.md))

        if (state.googleConfigured) {
            SocialButton(
                label = "Continue with Google",
                icon = Icons.Filled.AccountCircle,
                onClick = { viewModel.onGoogleClicked(context) },
                loading = state.googleLoading,
            )
            DividerWithText(text = "or")
        }

        PrimaryButton(
            label = "Sign in with email",
            onClick = onSignIn,
            enabled = !state.form.submitting,
        )
        SecondaryButton(
            label = "Create an account",
            onClick = onSignUp,
            enabled = !state.form.submitting,
        )
        SecondaryButton(
            label = "Use a one-time email code",
            onClick = onUseEmailCode,
            enabled = !state.form.submitting,
        )

        Spacer(Modifier.height(Spacing.md))
        Text(
            text = "By continuing you agree to our Terms and Privacy Policy.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun DividerWithText(text: String) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        HorizontalDivider(modifier = Modifier.weight(1f))
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        HorizontalDivider(modifier = Modifier.weight(1f))
    }
}
