package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.ui.semantics.Role
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.auth.state.AuthEffect

@Composable
fun SignUpScreen(
    onShowMessage: (String) -> Unit,
    onBack: () -> Unit = {},
    onSignIn: () -> Unit = {},
    viewModel: SignUpViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AuthEffect.ShowMessage -> onShowMessage(effect.text)
                AuthEffect.NavigateToHome -> Unit
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
            EsTopBar(title = "Create account", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
            ) {
                Text(
                    text = "Get started",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.24).sp,
                    color = SevaInk900,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Free to join. Engineers complete a quick KYC after signing up.",
                    fontSize = 13.sp,
                    color = SevaInk500,
                )
                Spacer(Modifier.height(24.dp))

                ErrorBanner(message = state.form.errorMessage)

                EsField(
                    value = state.fullName,
                    onChange = viewModel::onFullNameChange,
                    label = "Full name",
                    placeholder = "Ravi Kumar",
                    error = state.fullNameError,
                    enabled = !state.form.submitting,
                )
                Spacer(Modifier.height(14.dp))
                EsField(
                    value = state.email,
                    onChange = viewModel::onEmailChange,
                    label = "Email",
                    placeholder = "name@yourdomain.com",
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
                    hint = "8+ chars, with at least one letter and one number",
                    error = state.passwordError,
                    enabled = !state.form.submitting,
                )

                Spacer(Modifier.height(20.dp))
                Text(
                    text = "I'm signing up as",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                )
                Spacer(Modifier.height(10.dp))
                // Title matches UserRole.HOSPITAL.displayName so the
                // persona the user picks at signup matches the
                // AccountTypeSection / role-editor / Profile-pill copy
                // they'll see immediately after Continue (Round 12 +
                // Round 14 + Round 28). The bare "Hospital" was the last
                // surface saying it differently from the rest of the app.
                RoleTile(
                    title = "Hospital admin",
                    subtitle = "Book biomedical engineers for repairs",
                    selected = state.role == UserRole.HOSPITAL,
                    enabled = !state.form.submitting,
                    onClick = { viewModel.onRoleChange(UserRole.HOSPITAL) },
                )
                Spacer(Modifier.height(10.dp))
                RoleTile(
                    title = "Biomedical engineer",
                    subtitle = "Pick up local repair jobs and get paid",
                    selected = state.role == UserRole.ENGINEER,
                    enabled = !state.form.submitting,
                    onClick = { viewModel.onRoleChange(UserRole.ENGINEER) },
                )

                Spacer(Modifier.height(24.dp))
                EsBtn(
                    text = "Continue",
                    onClick = viewModel::onSubmit,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !state.canSubmit || state.form.submitting,
                )

                Spacer(Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = "Already have an account? ",
                        fontSize = 13.sp,
                        color = SevaInk600,
                    )
                    Text(
                        text = "Sign in",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaGreen700,
                        modifier = Modifier.clickable(onClick = onSignIn),
                    )
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun RoleTile(
    title: String,
    subtitle: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = if (selected) SevaGreen700 else BorderDefault
    val bgColor = if (selected) SevaGreen50 else Color.White
    Row(
        // Round 446 — selectable + Role.RadioButton (matches r445 fix on
        // the post-signup RoleSelectScreen). The signup-time pick is the
        // first interactive a11y surface a new user touches, so TalkBack
        // calling these "buttons" instead of "radio buttons" was a
        // disproportionately bad first impression.
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .let { m ->
                if (enabled) {
                    m.selectable(
                        selected = selected,
                        onClick = onClick,
                        role = Role.RadioButton,
                    )
                } else m
            }
            .background(bgColor)
            .border(1.dp, borderColor, RoundedCornerShape(10.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .border(2.dp, borderColor, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(SevaGreen700),
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = SevaInk900)
            Text(subtitle, fontSize = 12.sp, color = SevaInk500)
        }
    }
}
