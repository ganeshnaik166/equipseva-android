package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDeep
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

    AuthHeaderShell(
        eyebrow = "EMAIL CODE",
        title = "Email me a 6-digit code",
        subtitle = "No passwords. We'll send a fresh code to your inbox each time.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        // Friendly explainer card.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(BrandGreen50)
                .padding(horizontal = Spacing.md, vertical = Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Icon(
                imageVector = Icons.Outlined.Email,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(20.dp),
            )
            Text(
                text = "Codes expire in 10 minutes. Check spam if you don't see it.",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = BrandGreenDeep,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(Spacing.xs))

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
