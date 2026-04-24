package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.EquipSevaLogo
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PremiumGradientSurface
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun OtpRequestScreen(
    onCodeSent: (email: String) -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: OtpRequestViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.NavigateToOtpVerify -> onCodeSent(effect.email)
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
                text = "Sign in with email code",
                style = MaterialTheme.typography.displayMedium,
                color = BrandGreenDark,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = "We'll email you a 6-digit code. No password needed.",
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
                onImeAction = viewModel::onSubmit,
            )

            Spacer(Modifier.height(Spacing.sm))

            PrimaryButton(
                label = if (state.form.submitting) "Sending…" else "Send code",
                onClick = viewModel::onSubmit,
                enabled = state.canSubmit,
                loading = state.form.submitting,
            )
        }
    }
}
