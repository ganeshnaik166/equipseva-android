package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0

/**
 * Welcome screen — phone-OTP-only entry point. Single CTA "Continue with
 * phone" routes to the phone-OTP request flow. Email/password/Google were
 * stripped along with the auth pivot; this screen is now a brand-led intro
 * with one tap to onboarding.
 *
 * `onSignUp` / `onUseEmailCode` parameters stay for ABI compatibility with
 * older nav-graph wiring; both forward to `onUsePhone` so any caller that
 * routes to them ends up at the same place.
 */
@Composable
fun WelcomeScreen(
    onUsePhone: () -> Unit,
    @Suppress("UNUSED_PARAMETER") onSignIn: () -> Unit = onUsePhone,
    @Suppress("UNUSED_PARAMETER") onSignUp: () -> Unit = onUsePhone,
    @Suppress("UNUSED_PARAMETER") onUseEmailCode: () -> Unit = onUsePhone,
    @Suppress("UNUSED_PARAMETER") onShowMessage: (String) -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface0),
    ) {
        // Hero: full-bleed gradient + logo + tagline. Curved bottom hands off
        // to the white panel below.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(BrandGreenDeep, BrandGreen),
                    ),
                    shape = RoundedCornerShape(bottomStart = 40.dp, bottomEnd = 40.dp),
                )
                .padding(horizontal = Spacing.xl, vertical = 56.dp),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color.White.copy(alpha = 0.95f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.ic_logo_full),
                        contentDescription = "EquipSeva",
                        modifier = Modifier.size(64.dp).clip(RoundedCornerShape(14.dp)),
                    )
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(AccentLime.copy(alpha = 0.18f))
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = "INDIA · MEDICAL EQUIPMENT",
                        color = AccentLime,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.2.sp,
                    )
                }
                Text(
                    text = "Repair done right,\nby verified engineers.",
                    color = Color.White,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    lineHeight = 36.sp,
                )
                Text(
                    text = "Hospitals book biomedical engineers in their city. Engineers find verified jobs nearby.",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Spacer(Modifier.height(Spacing.xl))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            PrimaryButton(
                label = "Continue with phone",
                onClick = onUsePhone,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                text = "Sign in or sign up — same flow. We send a one-time code to your number.",
                color = Ink500,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.height(Spacing.xl))

        Text(
            text = "By continuing you agree to our Terms + Privacy Policy.",
            color = Ink900.copy(alpha = 0.6f),
            fontSize = 11.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.xl, vertical = Spacing.md),
        )
    }
}
