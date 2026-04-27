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
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
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

/**
 * Welcome screen — full-bleed gradient hero (BrandGreenDeep -> BrandGreen) with
 * curved bottom that hands off to a white panel containing the primary CTAs.
 * Modern Indian gig-app feel: warm, confident, brand-led.
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
                .verticalScroll(rememberScrollState()),
        ) {
            HeroBlock()

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.xl)
                    .padding(top = Spacing.xl, bottom = Spacing.xl)
                    .windowInsetsPadding(WindowInsets.systemBars),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                ErrorBanner(message = state.form.errorMessage)

                // Primary action — Create account.
                PrimaryButton(
                    label = "Create account",
                    onClick = onSignUp,
                )

                // Secondary action — Sign in (outlined-style card).
                AuthCardButton(
                    label = "I already have an account",
                    onClick = onSignIn,
                    style = CardStyle.Outline,
                )

                Spacer(Modifier.height(Spacing.xs))

                // OR divider
                OrDivider()

                Spacer(Modifier.height(Spacing.xs))

                if (state.googleConfigured) {
                    AuthCardButton(
                        label = "Continue with Google",
                        leading = { GoogleGlyph() },
                        loading = state.googleLoading,
                        onClick = { viewModel.onGoogleClicked(context) },
                        style = CardStyle.Soft,
                    )
                }

                AuthCardButton(
                    label = "Continue with phone (OTP)",
                    leading = {
                        IconBubble(icon = Icons.Filled.PhoneAndroid)
                    },
                    onClick = onUsePhone,
                    style = CardStyle.Soft,
                )

                Spacer(Modifier.height(Spacing.sm))

                // Engineer footer link.
                val engineerLine = buildAnnotatedString {
                    append("Already an engineer? ")
                    withStyle(
                        SpanStyle(color = BrandGreen, fontWeight = FontWeight.Bold),
                    ) { append("Phone-OTP sign-in →") }
                }
                Text(
                    text = engineerLine,
                    fontSize = 13.sp,
                    color = Ink700,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Spacing.sm))
                        .clickable(onClick = onUsePhone)
                        .padding(vertical = Spacing.sm),
                )

                // Email-OTP escape hatch (smaller, tertiary).
                Text(
                    text = "Or use a one-time email code",
                    fontSize = 12.sp,
                    color = Ink500,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Spacing.sm))
                        .clickable(onClick = onUseEmailCode)
                        .padding(vertical = Spacing.xs),
                )

                Spacer(Modifier.height(Spacing.sm))

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
}

/* ----- Hero block: full-bleed gradient with curved bottom + logo + tagline ---- */

@Composable
private fun HeroBlock() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(360.dp)
            .clip(RoundedCornerShape(bottomStart = 40.dp, bottomEnd = 40.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(BrandGreenDeep, BrandGreenDark, BrandGreen),
                ),
            ),
    ) {
        // Subtle accent-lime glow blob, top-right.
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(end = 24.dp, top = 80.dp)
                .size(140.dp)
                .clip(CircleShape)
                .background(AccentLimeSoft),
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .padding(horizontal = Spacing.xl)
                .padding(top = Spacing.xl, bottom = Spacing.xxl),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            // Logo mark.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(Surface0),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.ic_logo_full),
                        contentDescription = "EquipSeva logo",
                        modifier = Modifier.size(40.dp),
                    )
                }
                Text(
                    text = "EquipSeva",
                    color = Surface0,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.2).sp,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                // Pill chip — accent-lime.
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(AccentLime)
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Bolt,
                        contentDescription = null,
                        tint = BrandGreenDeep,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = "INDIA · MEDICAL EQUIPMENT",
                        color = BrandGreenDeep,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 0.6.sp,
                    )
                }

                Text(
                    text = "Repair done right,\nby verified engineers.",
                    color = Surface0,
                    fontSize = 30.sp,
                    lineHeight = 36.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.6).sp,
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.VerifiedUser,
                        contentDescription = null,
                        tint = AccentLime,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = "Trusted by hospitals across India",
                        color = Surface0.copy(alpha = 0.85f),
                        fontSize = 13.sp,
                    )
                }
            }
        }
    }
}

/* ----- Reusable helpers ----- */

private enum class CardStyle { Soft, Outline }

@Composable
private fun AuthCardButton(
    label: String,
    onClick: () -> Unit,
    leading: (@Composable () -> Unit)? = null,
    loading: Boolean = false,
    style: CardStyle = CardStyle.Outline,
) {
    val bg = if (style == CardStyle.Soft) BrandGreen50 else Surface0
    val borderColor = if (style == CardStyle.Soft) BrandGreen50 else Surface200
    val textColor = Ink900

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(bg)
            .border(width = 1.dp, color = borderColor, shape = RoundedCornerShape(28.dp))
            .clickable(enabled = !loading, onClick = onClick)
            .padding(horizontal = Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(28.dp), contentAlignment = Alignment.Center) {
                leading()
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
                color = BrandGreen,
            )
        }
    }
}

@Composable
private fun IconBubble(icon: ImageVector) {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(BrandGreen50),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun OrDivider() {
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

/**
 * Small "G" glyph stand-in for Google. Avoids shipping the multi-color asset.
 */
@Composable
private fun GoogleGlyph() {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(Color.White)
            .border(1.dp, Surface200, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "G",
            fontSize = 16.sp,
            fontWeight = FontWeight.Black,
            color = Color(0xFF4285F4),
        )
    }
}
