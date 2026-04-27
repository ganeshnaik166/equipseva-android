package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.MarkEmailRead
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.OtpField
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
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

    AuthHeaderShell(
        eyebrow = "VERIFY",
        title = "Enter the 6-digit code",
        subtitle = "We just sent it to your email — it expires in 10 minutes.",
    ) {
        ErrorBanner(message = state.form.errorMessage)

        // "Sent to <email>" pill.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(BrandGreen50)
                .padding(horizontal = Spacing.md, vertical = Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(BrandGreen),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.MarkEmailRead,
                    contentDescription = null,
                    tint = BrandGreen50,
                    modifier = Modifier.size(16.dp),
                )
            }
            Text(
                text = "Sent to $displayedEmail",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = BrandGreenDeep,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(Spacing.xs))

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

        // Resend timer + tip row.
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
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
        }

        Text(
            text = "Tip: tap the link in the confirmation email instead of typing the code.",
            fontSize = 12.sp,
            color = Ink700,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Suppress("unused")
private val Reserved = Ink900
