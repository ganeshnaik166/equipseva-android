package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EquipSevaLogo
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.OtpDigitField
import com.equipseva.app.designsystem.components.PremiumGradientSurface
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink400
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun OtpVerifyScreen(
    email: String,
    onShowMessage: (String) -> Unit,
    viewModel: OtpVerifyViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(email) {
        viewModel.setEmail(email)
    }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                AuthEffect.NavigateToHome -> Unit // SessionViewModel handles routing.
                else -> Unit
            }
        }
    }

    val displayedEmail = state.email.ifBlank { email }

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
                text = "Enter the code",
                style = MaterialTheme.typography.displayMedium,
                color = BrandGreenDark,
                modifier = Modifier.semantics { heading() },
            )
            // Subline shows email used; emphasise the address.
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Sent to ",
                    style = MaterialTheme.typography.bodyLarge,
                    color = Ink500,
                )
                Text(
                    text = displayedEmail,
                    style = MaterialTheme.typography.bodyLarge,
                    color = Ink900,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            Spacer(Modifier.height(Spacing.sm))

            ErrorBanner(message = state.form.errorMessage)

            OtpDigitField(
                value = state.code,
                onValueChange = viewModel::onCodeChange,
                length = 8,
                error = state.codeError,
            )

            // Resend countdown / link.
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Didn't receive it? ",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Ink500,
                )
                if (state.canResend) {
                    TextButton(onClick = viewModel::onResend, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                        Text(
                            text = "Resend code",
                            style = MaterialTheme.typography.bodyMedium,
                            color = BrandGreen,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                } else {
                    Text(
                        text = "Resend in ${state.resendSecondsRemaining}s",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Ink400,
                    )
                }
            }

            Spacer(Modifier.height(Spacing.sm))

            PrimaryButton(
                label = if (state.form.submitting) "Verifying…" else "Verify",
                onClick = viewModel::onSubmit,
                enabled = state.canSubmit,
                loading = state.form.submitting,
            )

            Spacer(Modifier.height(Spacing.xs))

            Text(
                text = "Tip: tap the link in the confirmation email instead of typing the code.",
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
            )
        }
    }
}
