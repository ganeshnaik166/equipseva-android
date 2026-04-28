package com.equipseva.app.features.auth

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
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun SignInScreen(
    onBack: () -> Unit,
    onForgotPassword: () -> Unit,
    onCreateAccount: () -> Unit,
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

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .imePadding()
                .verticalScroll(rememberScrollState()),
        ) {
            EsTopBar(title = "Sign in", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
            ) {
                Text(
                    text = "Welcome back",
                    style = EsType.H3,
                    color = SevaInk900,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Sign in to your EquipSeva account.",
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
                Spacer(Modifier.height(24.dp))

                ErrorBanner(message = state.form.errorMessage)

                EsField(
                    value = state.email,
                    onChange = viewModel::onEmailChange,
                    label = "Email",
                    placeholder = "you@hospital.com",
                    type = EsFieldType.Email,
                    error = state.emailError,
                    enabled = !state.form.submitting,
                )
                Spacer(Modifier.height(14.dp))
                EsField(
                    value = state.password,
                    onChange = viewModel::onPasswordChange,
                    label = "Password",
                    type = EsFieldType.Password,
                    error = state.passwordError,
                    enabled = !state.form.submitting,
                )
                // Forgot link, right-aligned.
                Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
                    Text(
                        text = "Forgot password?",
                        style = EsType.Caption.copy(fontWeight = FontWeight.SemiBold),
                        color = SevaGreen700,
                        modifier = Modifier.clickable(enabled = !state.form.submitting, onClick = onForgotPassword),
                    )
                }

                Spacer(Modifier.height(24.dp))
                EsBtn(
                    text = "Sign in",
                    onClick = viewModel::onSubmit,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !state.canSubmit || state.form.submitting,
                )
                Spacer(Modifier.height(16.dp))
                OrDivider()
                Spacer(Modifier.height(16.dp))
                // Google sign-in button — no leading icon yet (round B
                // doesn't yet ship the multi-colour Google glyph SVG).
                EsBtn(
                    text = "Continue with Google",
                    onClick = viewModel::onSubmit,
                    kind = EsBtnKind.Secondary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = state.form.submitting,
                )

                Spacer(Modifier.height(20.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = "New here? ",
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                    Text(
                        text = "Create account",
                        style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                        color = SevaGreen700,
                        modifier = Modifier.clickable(onClick = onCreateAccount),
                    )
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun OrDivider() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(modifier = Modifier.weight(1f).height(1.dp).background(BorderDefault))
        Text(text = "or", style = EsType.Caption, color = SevaInk500, textAlign = TextAlign.Center)
        Box(modifier = Modifier.weight(1f).height(1.dp).background(BorderDefault))
    }
}
