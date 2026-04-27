package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.AuthScaffold
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success

@Composable
fun ForgotPasswordScreen(
    onBack: () -> Unit,
    viewModel: ForgotPasswordViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    if (state.sent) {
        AuthScaffold(
            title = "Check your email",
            subtitle = "We've sent a password reset link to ${state.email.trim()}.",
        ) {
            SentContent(onBack = onBack)
        }
    } else {
        AuthScaffold(
            title = "Reset your password",
            subtitle = "Enter the email you use for EquipSeva and we'll send a link to reset your password.",
        ) {
            ErrorBanner(message = state.errorMessage)

            EmailField(
                value = state.email,
                onValueChange = viewModel::onEmailChange,
                enabled = !state.submitting,
                isError = state.emailError != null,
                errorText = state.emailError,
                imeAction = ImeAction.Done,
                onImeAction = viewModel::onSubmit,
            )

            Spacer(Modifier.height(Spacing.sm))

            PrimaryButton(
                label = "Send reset link",
                onClick = viewModel::onSubmit,
                enabled = state.email.isNotBlank() && !state.submitting,
                loading = state.submitting,
            )
        }
    }
}

@Composable
private fun SentContent(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = Success,
            modifier = Modifier
                .size(72.dp)
                .semantics { heading() },
        )
        Text(
            text = "Didn't get it? Check your spam folder or try again in a minute.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(Spacing.sm))
        SecondaryButton(
            label = "Back to sign in",
            onClick = onBack,
        )
    }
}
