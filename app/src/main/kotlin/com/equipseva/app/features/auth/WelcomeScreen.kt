package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.auth.state.AuthEffect

/**
 * Pinterest-style welcome: big circular brand logo, bold tagline, stacked
 * auth-option cards (Google / Phone / Email), single sign-in link at the
 * bottom. Pure white background with the only colour coming from the brand
 * logo + the primary "Continue with email" CTA.
 */
@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
    onUseEmailCode: () -> Unit,
    onUsePhone: () -> Unit = {},
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

    Surface(modifier = Modifier.fillMaxSize(), color = Surface0) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.lg)
                .padding(top = 32.dp, bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Hero — big brand-green circle with the logo mark, brand name + welcome line.
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            listOf(BrandGreen, BrandGreenDark),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    painter = painterResource(id = R.drawable.ic_logo_full),
                    contentDescription = "EquipSeva logo",
                    modifier = Modifier.size(80.dp),
                )
            }

            Spacer(Modifier.height(20.dp))

            Text(
                text = "Welcome to EquipSeva",
                fontSize = 28.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.6).sp,
                color = Ink900,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Find parts, dispatch repairs, and run your hospital equipment in one place.",
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = Ink500,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = Spacing.md),
            )

            Spacer(Modifier.height(36.dp))

            ErrorBanner(message = state.form.errorMessage)

            // Auth-option stack — each row is a tappable card.
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (state.googleConfigured) {
                    AuthOptionCard(
                        icon = ProviderIcon.Google,
                        label = "Continue with Google",
                        loading = state.googleLoading,
                        onClick = { viewModel.onGoogleClicked(context) },
                    )
                }
                AuthOptionCard(
                    icon = ProviderIcon.Generic(Icons.Filled.PhoneAndroid),
                    label = "Continue with phone",
                    loading = false,
                    onClick = onUsePhone,
                )
                AuthOptionCard(
                    icon = ProviderIcon.Generic(Icons.Outlined.Email),
                    label = "Continue with email & password",
                    loading = false,
                    onClick = onSignIn,
                    primary = true,
                )
                AuthOptionCard(
                    icon = ProviderIcon.Generic(Icons.AutoMirrored.Filled.ArrowForward),
                    label = "Use a one-time email code",
                    loading = false,
                    onClick = onUseEmailCode,
                    subtle = true,
                )
            }

            Spacer(Modifier.height(28.dp))

            // Sign-up nudge — Pinterest pattern: "Not on EquipSeva yet? Sign up"
            val nudge = buildAnnotatedString {
                append("New to EquipSeva? ")
                withStyle(
                    SpanStyle(
                        color = BrandGreen,
                        fontWeight = FontWeight.Bold,
                    ),
                ) { append("Create an account") }
            }
            Text(
                text = nudge,
                fontSize = 14.sp,
                color = Ink700,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClick = onSignUp)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )

            Spacer(Modifier.height(20.dp))

            Text(
                text = "By continuing, you agree to the Terms and Privacy Policy.",
                fontSize = 11.sp,
                color = Ink500,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.md),
            )
        }
    }
}

private sealed interface ProviderIcon {
    data object Google : ProviderIcon
    data class Generic(val image: ImageVector) : ProviderIcon
}

@Composable
private fun AuthOptionCard(
    icon: ProviderIcon,
    label: String,
    loading: Boolean,
    onClick: () -> Unit,
    primary: Boolean = false,
    subtle: Boolean = false,
) {
    val bg = when {
        primary -> BrandGreen50
        else -> Surface0
    }
    val borderColor = when {
        primary -> BrandGreen
        subtle -> Color.Transparent
        else -> Surface200
    }
    val textColor = if (primary) BrandGreenDark else Ink900

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(bg)
            .border(
                width = if (subtle) 0.dp else if (primary) 1.5.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(28.dp),
            )
            .clickable(enabled = !loading, onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier.size(24.dp),
            contentAlignment = Alignment.Center,
        ) {
            when (icon) {
                ProviderIcon.Google -> GoogleGlyph()
                is ProviderIcon.Generic -> Icon(
                    imageVector = icon.image,
                    contentDescription = null,
                    tint = textColor,
                    modifier = Modifier.size(22.dp),
                )
            }
        }
        Text(
            text = label,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = textColor,
            modifier = Modifier.weight(1f),
        )
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                strokeWidth = 2.dp,
                color = textColor,
            )
        }
    }
}

/**
 * Tiny "G" glyph for the Google card. Drawing it inline avoids shipping the
 * Material Symbols Google logo asset and keeps the brand green/red/yellow
 * pop without a vector file.
 */
@Composable
private fun GoogleGlyph() {
    Box(
        modifier = Modifier
            .size(24.dp)
            .clip(CircleShape)
            .background(Color.White)
            .border(1.dp, Surface200, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "G",
            fontSize = 15.sp,
            fontWeight = FontWeight.Black,
            color = Color(0xFF4285F4),
        )
    }
}
