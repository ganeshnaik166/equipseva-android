package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EquipSevaLogo
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PremiumGradientSurface
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.components.SocialButton
import com.equipseva.app.designsystem.components.TonalButton
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
    onUseEmailCode: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: WelcomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

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
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.xl, vertical = Spacing.xl),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    EquipSevaLogo(
                        height = 44.dp,
                        contentDescription = "EquipSeva logo",
                    )
                    Text(
                        text = "EquipSeva",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.SemiBold,
                        letterSpacing = (-0.4).sp,
                        color = BrandGreenDark,
                    )
                }
                Spacer(Modifier.height(Spacing.xxxl))
                Text(
                    text = "Equipment that's always ready.",
                    style = MaterialTheme.typography.displayLarge,
                    color = BrandGreenDark,
                )
                Spacer(Modifier.height(Spacing.md))
                Text(
                    text = "Parts marketplace, repair dispatch, and UPI billing — built for hospitals, suppliers, and field engineers across India.",
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    color = Ink500,
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                ErrorBanner(message = state.form.errorMessage)

                if (state.googleConfigured) {
                    SocialButton(
                        label = "Continue with Google",
                        icon = Icons.Filled.AccountCircle,
                        onClick = { viewModel.onGoogleClicked(context) },
                        loading = state.googleLoading,
                    )
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
                }

                PrimaryButton(
                    label = "Sign in",
                    onClick = onSignIn,
                    enabled = !state.form.submitting,
                )
                TonalButton(
                    label = "Create account",
                    onClick = onSignUp,
                    enabled = !state.form.submitting,
                )
                SecondaryButton(
                    label = "Use a one-time email code",
                    onClick = onUseEmailCode,
                    enabled = !state.form.submitting,
                )

                Spacer(Modifier.height(Spacing.xs))
                Text(
                    text = "By continuing, you accept the Terms and Privacy Policy.",
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    color = Ink500,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.height(Spacing.xs))
            Box(modifier = Modifier.fillMaxWidth())
        }
    }
}
