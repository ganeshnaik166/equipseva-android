package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.ClickableText
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.core.net.toUri
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGreen900
import android.content.Intent

// Round B redesign — full-bleed dark green hero with logo + tagline,
// two CTAs at the bottom (lime "Sign in" + outlined "Create account"),
// 11sp legal text. Matches `screens-auth.jsx:Welcome`.
@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
) {
    val context = LocalContext.current

    Surface(modifier = Modifier.fillMaxSize(), color = SevaGreen900) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .padding(horizontal = 24.dp, vertical = 40.dp),
        ) {
            // Top + middle: logo + brand + tagline.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.Center,
            ) {
                Image(
                    painter = painterResource(R.drawable.ic_logo_mark),
                    contentDescription = "EquipSeva",
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(16.dp)),
                )
                Spacer(Modifier.height(28.dp))
                Text(
                    text = "EquipSeva",
                    fontFamily = EsFontFamily,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    lineHeight = 38.sp,
                    letterSpacing = (-0.72).sp, // -0.02em × 36sp
                    color = Color.White,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "Hospitals book verified biomedical engineers. Engineers find local jobs and get paid on time.",
                    fontFamily = EsFontFamily,
                    fontSize = 16.sp,
                    lineHeight = 23.sp,
                    color = Color.White.copy(alpha = 0.75f),
                )
            }

            // Bottom: CTAs + legal.
            EsBtn(
                text = "Sign in",
                onClick = onSignIn,
                kind = EsBtnKind.Lime,
                size = EsBtnSize.Lg,
                full = true,
            )
            Spacer(Modifier.height(10.dp))
            // "Create account" — outlined transparent on dark bg. EsBtn doesn't
            // ship a transparent-on-dark variant, so render a custom outlined
            // button here. Matches the design's inline `boxShadow: inset 0 0 0
            // 1px rgba(255,255,255,0.3)` pattern.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(8.dp))
                    .background(Color.Transparent)
                    .clickable(onClick = onSignUp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Create account",
                    fontFamily = EsFontFamily,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White,
                )
            }
            Spacer(Modifier.height(12.dp))
            // Terms + Privacy as tappable spans. Required for Play Store
            // listing compliance + IT Act 2000 informed-consent — saying
            // "you agree" without a way to read the agreement is hostile
            // UX and a Play policy risk.
            val termsTag = "TERMS"
            val privacyTag = "PRIVACY"
            val baseColor = Color.White.copy(alpha = 0.55f)
            val linkColor = Color.White.copy(alpha = 0.85f)
            val annotated = buildAnnotatedString {
                withStyle(SpanStyle(color = baseColor)) {
                    append("By continuing you agree to our ")
                }
                pushStringAnnotation(termsTag, "https://equipseva.com/terms")
                withStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)) {
                    append("Terms")
                }
                pop()
                withStyle(SpanStyle(color = baseColor)) {
                    append(" and ")
                }
                pushStringAnnotation(privacyTag, "https://equipseva.com/privacy")
                withStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)) {
                    append("Privacy")
                }
                pop()
            }
            ClickableText(
                text = annotated,
                style = TextStyle(
                    fontFamily = EsFontFamily,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                ),
                modifier = Modifier.fillMaxWidth(),
                onClick = { offset ->
                    val tag = annotated.getStringAnnotations(termsTag, offset, offset).firstOrNull()
                        ?: annotated.getStringAnnotations(privacyTag, offset, offset).firstOrNull()
                    tag?.item?.let { url ->
                        runCatching {
                            context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
                        }
                    }
                },
            )
        }
    }
}
