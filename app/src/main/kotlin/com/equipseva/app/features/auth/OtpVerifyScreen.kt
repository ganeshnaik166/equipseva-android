package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.AuthScaffold
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.OtpField
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
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

    AuthScaffold(
        title = "Enter code",
        subtitle = "We sent a code to ${state.email.ifBlank { email }}. It expires in 10 minutes.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        OtpField(
            value = state.code,
            onValueChange = viewModel::onCodeChange,
            enabled = !state.form.submitting,
            isError = state.codeError != null,
            errorText = state.codeError,
            onSubmit = viewModel::onSubmit,
        )

        Spacer(Modifier.height(Spacing.sm))

        PrimaryButton(
            label = "Verify",
            onClick = viewModel::onSubmit,
            enabled = state.canSubmit,
            loading = state.form.submitting,
        )

        TextButton(
            onClick = viewModel::onResend,
            enabled = state.canResend,
        ) {
            Text(
                text = if (state.resendSecondsRemaining > 0) {
                    "Resend code in ${state.resendSecondsRemaining}s"
                } else {
                    "Resend code"
                },
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (state.canResend) BrandGreen else Ink500,
            )
        }

        Text(
            text = "Tip: tap the link in the confirmation email instead of typing the code.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
