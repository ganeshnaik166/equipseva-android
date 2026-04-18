package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
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
import com.equipseva.app.designsystem.components.PasswordField
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun SignInScreen(
    onUseOtpInstead: () -> Unit,
    onForgotPassword: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: SignInViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

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
        title = "Sign in",
        subtitle = "Welcome back. Use your email and password.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        EmailField(
            value = state.email,
            onValueChange = viewModel::onEmailChange,
            enabled = !state.form.submitting,
            isError = state.emailError != null,
            errorText = state.emailError,
            imeAction = ImeAction.Next,
        )

        PasswordField(
            value = state.password,
            onValueChange = viewModel::onPasswordChange,
            enabled = !state.form.submitting,
            isError = state.passwordError != null,
            errorText = state.passwordError,
            imeAction = ImeAction.Done,
            onImeAction = viewModel::onSubmit,
        )

        Spacer(Modifier.height(Spacing.sm))

        PrimaryButton(
            label = "Sign in",
            onClick = viewModel::onSubmit,
            enabled = state.canSubmit,
            loading = state.form.submitting,
        )

        TextButton(onClick = onUseOtpInstead, enabled = !state.form.submitting) {
            Text("Email me a one-time code instead")
        }

        TextButton(onClick = onForgotPassword, enabled = !state.form.submitting) {
            Text("Forgot password?")
        }
    }
}
