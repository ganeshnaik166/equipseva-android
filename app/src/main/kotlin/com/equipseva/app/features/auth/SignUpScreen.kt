package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
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
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun SignUpScreen(
    onOtpVerifyRequested: (email: String) -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: SignUpViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.NavigateToOtpVerify -> onOtpVerifyRequested(effect.email)
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                else -> Unit
            }
        }
    }

    AuthHeaderShell(
        eyebrow = "GET STARTED",
        title = "Create your account",
        subtitle = "Drop your email — we'll send a 6-digit code. No password needed yet.",
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

        Spacer(Modifier.height(Spacing.md))

        // Value props — three quick benefit chips, gig-app style.
        BenefitsList()
    }
}

@Composable
private fun BenefitsList() {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        BenefitRow(text = "Verified engineers within 24 hours")
        BenefitRow(text = "Genuine OEM parts, traceable invoices")
        BenefitRow(text = "Pay after the job is done")
    }
}

@Composable
private fun BenefitRow(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AccentLimeSoft)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(BrandGreen),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = null,
                tint = AccentLimeSoft,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            text = text,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = BrandGreenDeep,
            modifier = Modifier.weight(1f),
        )
    }
}

// Keep an unused-but-referenced color in scope to avoid lint complaints.
@Suppress("unused")
private val FooterAccent = Ink700
