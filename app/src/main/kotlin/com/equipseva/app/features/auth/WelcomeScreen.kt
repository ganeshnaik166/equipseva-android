package com.equipseva.app.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.util.openExternalUrl
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGreen900

private const val TERMS_URL = "https://equipseva.com/terms"
private const val PRIVACY_URL = "https://equipseva.com/privacy"

@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
) {
    val context = LocalContext.current
    WelcomeContent(
        onSignIn = onSignIn,
        onSignUp = onSignUp,
        onTerms = { openExternalUrl(context, TERMS_URL) },
        onPrivacy = { openExternalUrl(context, PRIVACY_URL) },
    )
}

/** Stateless content keeps the legal actions independently testable offline. */
@Composable
internal fun WelcomeContent(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
    onTerms: () -> Unit,
    onPrivacy: () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize(), color = SevaGreen900) {
        BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.systemBars)) {
            val compact = maxHeight < 600.dp
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .heightIn(min = maxHeight)
                    .padding(horizontal = 24.dp, vertical = if (compact) 16.dp else 24.dp),
                verticalArrangement = if (compact) Arrangement.Top else Arrangement.SpaceBetween,
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = if (compact) 0.dp else 32.dp),
                    verticalArrangement = Arrangement.Center,
                ) {
                    Image(
                        painter = painterResource(R.drawable.ic_logo_mark),
                        contentDescription = null,
                        modifier = Modifier
                            .size(if (compact) 48.dp else 64.dp)
                            .clip(RoundedCornerShape(16.dp)),
                    )
                    Spacer(Modifier.height(if (compact) 12.dp else 28.dp))
                    Text(
                        text = stringResource(R.string.app_name),
                        fontFamily = EsFontFamily,
                        fontSize = if (compact) 28.sp else 36.sp,
                        fontWeight = FontWeight.Bold,
                        lineHeight = if (compact) 34.sp else 38.sp,
                        letterSpacing = (-0.72).sp,
                        color = Color.White,
                    )
                    if (!compact) {
                        Spacer(Modifier.height(12.dp))
                        WelcomeTagline()
                    }
                }

                if (compact) Spacer(Modifier.height(16.dp))
                Column(Modifier.fillMaxWidth()) {
                    EsBtn(
                        text = "Sign in",
                        onClick = onSignIn,
                        kind = EsBtnKind.Lime,
                        size = EsBtnSize.Lg,
                        full = true,
                    )
                    Spacer(Modifier.height(10.dp))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(8.dp))
                            .background(Color.Transparent)
                            .clickable(role = Role.Button, onClick = onSignUp)
                            .defaultMinSize(minHeight = 52.dp)
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = stringResource(R.string.welcome_create_account),
                            fontFamily = EsFontFamily,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            textAlign = TextAlign.Center,
                            color = Color.White,
                        )
                    }
                    if (compact) {
                        Spacer(Modifier.height(16.dp))
                        WelcomeTagline()
                    }
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "By continuing you agree to our",
                        fontFamily = EsFontFamily,
                        fontSize = 12.sp,
                        lineHeight = 18.sp,
                        textAlign = TextAlign.Center,
                        color = Color.White.copy(alpha = 0.75f),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LegalAction("Terms", onTerms)
                        Text("and", fontSize = 12.sp, color = Color.White.copy(alpha = 0.75f))
                        LegalAction("Privacy", onPrivacy)
                    }
                }
            }
        }
    }
}

@Composable
private fun WelcomeTagline() {
    Text(
        text = stringResource(R.string.welcome_tagline),
        fontFamily = EsFontFamily,
        fontSize = 16.sp,
        lineHeight = 23.sp,
        color = Color.White.copy(alpha = 0.75f),
    )
}

@Composable
private fun LegalAction(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .defaultMinSize(minWidth = 64.dp, minHeight = 48.dp)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontFamily = EsFontFamily,
            fontSize = 12.sp,
            lineHeight = 18.sp,
            textDecoration = TextDecoration.Underline,
            color = Color.White,
        )
    }
}
