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
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.EquipSevaLogo
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PasswordField
import com.equipseva.app.designsystem.components.PremiumGradientSurface
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
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
                AuthEffect.NavigateToHome -> Unit
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
                text = "Welcome back",
                style = MaterialTheme.typography.displayMedium,
                color = BrandGreenDark,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = "Sign in to continue to EquipSeva.",
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

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                TextButton(onClick = onForgotPassword, enabled = !state.form.submitting) {
                    Text(
                        "Forgot password?",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BrandGreen,
                    )
                }
            }

            PrimaryButton(
                label = if (state.form.submitting) "Signing in…" else "Sign in",
                onClick = viewModel::onSubmit,
                enabled = state.canSubmit,
                loading = state.form.submitting,
            )

            Spacer(Modifier.height(Spacing.xs))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                HorizontalDivider(modifier = Modifier.weight(1f))
                Text(
                    text = "OR",
                    style = MaterialTheme.typography.labelSmall,
                    color = Ink500,
                    fontWeight = FontWeight.SemiBold,
                )
                HorizontalDivider(modifier = Modifier.weight(1f))
            }

            SecondaryButton(
                label = "Email me a one-time code",
                onClick = onUseOtpInstead,
                enabled = !state.form.submitting,
            )
        }
    }
}
