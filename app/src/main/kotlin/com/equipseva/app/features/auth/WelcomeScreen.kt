package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.components.SocialButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Info
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

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .drawBehind {
                    // Soft brand radial top-right
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(BrandGreen50, Color.Transparent),
                            center = Offset(size.width + 120.dp.toPx(), -120.dp.toPx()),
                            radius = 400.dp.toPx(),
                        ),
                        radius = 400.dp.toPx(),
                        center = Offset(size.width + 120.dp.toPx(), -120.dp.toPx()),
                    )
                    // Blue radial bottom-left
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(Info.copy(alpha = 0.08f), Color.Transparent),
                            center = Offset(-80.dp.toPx(), size.height + 80.dp.toPx()),
                            radius = 300.dp.toPx(),
                        ),
                        radius = 300.dp.toPx(),
                        center = Offset(-80.dp.toPx(), size.height + 80.dp.toPx()),
                    )
                },
        ) {
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
                        Image(
                            painter = painterResource(id = R.drawable.ic_logo_mark),
                            contentDescription = "EquipSeva logo",
                            modifier = Modifier.size(44.dp),
                        )
                        Text(
                            text = "EquipSeva",
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = (-0.4).sp,
                            color = Ink900,
                        )
                    }
                    Spacer(Modifier.height(48.dp))
                    Text(
                        text = "The operating layer for Indian hospital equipment.",
                        fontSize = 34.sp,
                        lineHeight = 40.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-1.2).sp,
                        color = Ink900,
                    )
                    Spacer(Modifier.height(Spacing.md))
                    Text(
                        text = "Parts marketplace, repair dispatch, and UPI billing — in one app built for the field.",
                        fontSize = 15.sp,
                        lineHeight = 22.sp,
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
                    SecondaryButton(
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
                        color = Ink500,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}
