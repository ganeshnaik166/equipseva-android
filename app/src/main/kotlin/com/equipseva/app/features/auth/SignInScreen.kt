package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EmailField
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PasswordField
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
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

    AuthHeaderShell(
        eyebrow = "WELCOME BACK",
        title = "Sign in to EquipSeva",
        subtitle = "Pick up where you left off — orders, parts, and engineers.",
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
            label = "Sign in",
            onClick = viewModel::onSubmit,
            enabled = state.canSubmit,
            loading = state.form.submitting,
        )

        Spacer(Modifier.height(Spacing.xs))

        OrDividerLine()

        Spacer(Modifier.height(Spacing.xs))

        // Phone-OTP secondary path.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(BrandGreen50)
                .clickable(enabled = !state.form.submitting, onClick = onUseOtpInstead),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Email me a one-time code",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = BrandGreenDark,
            )
        }

        Spacer(Modifier.height(Spacing.md))

        // No-account nudge — still routes via onUseOtpInstead's parent in nav graph;
        // we keep this purely as a footer hint (no callback wiring change).
        Text(
            text = "Tip: new users can skip the password and sign in with a code.",
            fontSize = 12.sp,
            color = Ink500,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/* ----- Shared header shell used by SignIn / SignUp / OtpRequest / OtpVerify ----- */

@Composable
internal fun AuthHeaderShell(
    eyebrow: String,
    title: String,
    subtitle: String,
    content: @Composable () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize(), color = Surface0) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .imePadding()
                .verticalScroll(rememberScrollState()),
        ) {
            // Top accent strip (gradient) — anchors the brand on every form.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(
                        Brush.horizontalGradient(
                            listOf(BrandGreenDeep, BrandGreen, BrandGreenDark),
                        ),
                    ),
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.xl)
                    .padding(top = Spacing.xl, bottom = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                // Logo + eyebrow row.
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(BrandGreen50),
                        contentAlignment = Alignment.Center,
                    ) {
                        Image(
                            painter = painterResource(id = R.drawable.ic_logo_full),
                            contentDescription = "EquipSeva logo",
                            modifier = Modifier.size(36.dp),
                        )
                    }
                    Text(
                        text = eyebrow,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 1.2.sp,
                        color = Ink500,
                    )
                }

                Spacer(Modifier.height(Spacing.xs))

                Text(
                    text = title,
                    fontSize = 26.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.4).sp,
                    color = Ink900,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = subtitle,
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    color = Ink700,
                )

                Spacer(Modifier.height(Spacing.sm))

                content()
            }
        }
    }
}

@Composable
internal fun OrDividerLine() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(Surface200),
        )
        Text(
            text = "OR",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
            color = Ink500,
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(Surface200),
        )
    }
}

@Composable
@Suppress("unused")
internal fun SwitchAuthLink(
    leading: String,
    actionLabel: String,
    onClick: () -> Unit,
) {
    val annotated = buildAnnotatedString {
        append("$leading ")
        withStyle(
            SpanStyle(color = BrandGreen, fontWeight = FontWeight.Bold),
        ) { append(actionLabel) }
    }
    Text(
        text = annotated,
        fontSize = 13.sp,
        color = Ink700,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Spacing.sm))
            .clickable(onClick = onClick)
            .padding(vertical = Spacing.sm),
    )
}
