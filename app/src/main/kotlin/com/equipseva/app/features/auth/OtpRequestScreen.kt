package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.AuthScaffold
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
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

    AuthScaffold(
        title = "Email me a code",
        subtitle = "We'll send a 6-digit code to your email. No password needed.",
    ) {
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
            label = "Send code",
            onClick = viewModel::onSubmit,
            enabled = state.canSubmit,
            loading = state.form.submitting,
        )
    }
}
