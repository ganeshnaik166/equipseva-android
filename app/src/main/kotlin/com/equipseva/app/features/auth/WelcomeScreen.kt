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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.util.openExternalUrl
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGlow
import com.equipseva.app.designsystem.theme.SevaGlowSoft
import com.equipseva.app.designsystem.theme.SevaGreen200
import com.equipseva.app.designsystem.theme.SevaGreen800
import com.equipseva.app.designsystem.theme.SevaGreen900

@Composable
fun WelcomeScreen(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
) {
    val context = LocalContext.current
    WelcomeContent(
        onSignIn = onSignIn,
        onSignUp = onSignUp,
        onTerms = { openExternalUrl(context, "https://equipseva.com/terms") },
        onPrivacy = { openExternalUrl(context, "https://equipseva.com/privacy") },
    )
}

/** Signed-out introduction only. Roles are confirmed by the existing auth flow. */
@Composable
internal fun WelcomeContent(
    onSignIn: () -> Unit,
    onSignUp: () -> Unit,
    onTerms: () -> Unit,
    onPrivacy: () -> Unit,
) {
    val largeText = LocalDensity.current.fontScale >= 1.5f
    // Every foreground is paired with this deliberate brand surface or the
    // panel/action surface below, including when the app uses its dark theme.
    Surface(modifier = Modifier.fillMaxSize(), color = SevaGreen900, contentColor = Color.White) {
        Box(
            modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.systemBars),
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 520.dp)
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp),
            ) {
                if (largeText) {
                    // Preserve the requested text scale. The wordmark gets the
                    // full width instead of being squeezed beside the logo.
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        WelcomeLogo()
                        WelcomeBrandName()
                    }
                } else {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        WelcomeLogo()
                        WelcomeBrandName()
                    }
                }
                Spacer(Modifier.height(24.dp))
                Text(
                    text = stringResource(R.string.welcome_tagline),
                    fontFamily = EsFontFamily,
                    fontSize = 24.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                )
                Spacer(Modifier.height(24.dp))
                WelcomeAudience(
                    title = stringResource(R.string.welcome_hospital_title),
                    description = stringResource(R.string.welcome_hospital_description),
                )
                Spacer(Modifier.height(10.dp))
                WelcomeAudience(
                    title = stringResource(R.string.welcome_engineer_title),
                    description = stringResource(R.string.welcome_engineer_description),
                )
                Spacer(Modifier.height(24.dp))
                WelcomeAction(
                    label = stringResource(R.string.welcome_sign_in),
                    onClick = onSignIn,
                    primary = true,
                )
                Spacer(Modifier.height(12.dp))
                WelcomeAction(
                    label = stringResource(R.string.welcome_create_account),
                    onClick = onSignUp,
                    primary = false,
                )
                Spacer(Modifier.height(20.dp))
                Text(
                    text = stringResource(R.string.welcome_legal_intro),
                    fontFamily = EsFontFamily,
                    fontSize = 14.sp,
                    lineHeight = 21.sp,
                    color = Color.White.copy(alpha = 0.85f),
                )
                Spacer(Modifier.height(8.dp))
                WelcomeLegalAction(stringResource(R.string.welcome_terms), onTerms)
                Spacer(Modifier.height(4.dp))
                WelcomeLegalAction(stringResource(R.string.welcome_privacy), onPrivacy)
            }
        }
    }
}

@Composable
private fun WelcomeLogo() {
    Image(
        painter = painterResource(R.drawable.ic_logo_mark),
        contentDescription = null,
        modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)),
    )
}

@Composable
private fun WelcomeBrandName() {
    Text(
        text = stringResource(R.string.app_name),
        modifier = Modifier.semantics { heading() },
        fontFamily = EsFontFamily,
        fontSize = 26.sp,
        lineHeight = 34.sp,
        fontWeight = FontWeight.Bold,
        color = Color.White,
    )
}

@Composable
private fun WelcomeAudience(title: String, description: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SevaGreen800, RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = title,
            fontFamily = EsFontFamily,
            fontSize = 16.sp,
            lineHeight = 23.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaGlowSoft,
        )
        Text(
            text = description,
            fontFamily = EsFontFamily,
            fontSize = 14.sp,
            lineHeight = 21.sp,
            color = Color.White.copy(alpha = 0.9f),
        )
    }
}

@Composable
private fun WelcomeAction(label: String, onClick: () -> Unit, primary: Boolean) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clip(shape)
            .background(if (primary) SevaGlow else SevaGreen900)
            .then(if (primary) Modifier else Modifier.border(1.dp, SevaGreen200, shape))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            modifier = Modifier.fillMaxWidth(),
            fontFamily = EsFontFamily,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            color = if (primary) SevaGreen900 else Color.White,
        )
    }
}

@Composable
private fun WelcomeLegalAction(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(8.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            modifier = Modifier.fillMaxWidth(),
            fontFamily = EsFontFamily,
            fontSize = 14.sp,
            lineHeight = 21.sp,
            textAlign = TextAlign.Center,
            textDecoration = TextDecoration.Underline,
            color = Color.White,
        )
    }
}
