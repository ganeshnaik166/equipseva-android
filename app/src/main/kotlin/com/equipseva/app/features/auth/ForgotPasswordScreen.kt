package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@Composable
fun ForgotPasswordScreen(
    onBack: () -> Unit,
    viewModel: ForgotPasswordViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .imePadding()
                .verticalScroll(rememberScrollState()),
        ) {
            EsTopBar(title = "Reset password", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
            ) {
                if (state.sent) {
                    SentBlock(email = state.email.trim().ifBlank { "your email" }, onBack = onBack)
                } else {
                    Text(
                        text = "Enter your email. We'll send a link to reset your password.",
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                    Spacer(Modifier.height(20.dp))

                    ErrorBanner(message = state.errorMessage)

                    EsField(
                        value = state.email,
                        onChange = viewModel::onEmailChange,
                        label = "Email",
                        placeholder = "you@hospital.com",
                        type = EsFieldType.Email,
                        error = state.emailError,
                        enabled = !state.submitting,
                    )

                    Spacer(Modifier.height(20.dp))
                    EsBtn(
                        text = "Send reset link",
                        onClick = viewModel::onSubmit,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = state.email.isBlank() || state.submitting,
                    )
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun SentBlock(email: String, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(32.dp),
            )
        }
        Spacer(Modifier.height(20.dp))
        Text(
            text = "Check your email",
            style = EsType.H4,
            color = SevaInk900,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = "We've sent a reset link to $email.",
            style = EsType.BodySm,
            color = SevaInk500,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        EsBtn(
            text = "Back to sign in",
            onClick = onBack,
            kind = EsBtnKind.Primary,
            size = EsBtnSize.Lg,
            full = true,
        )
    }
}
